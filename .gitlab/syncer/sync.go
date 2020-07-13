package main

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"time"

	"github.com/google/go-github/v32/github"
	"github.com/sirupsen/logrus"
	"github.com/xanzy/go-gitlab"
)

var log = logrus.New()

const (
	SourceProjectOwner = "piraeusdatastore"
	SourceProjectRepo  = "piraeus-operator"
	SubprojectPath     = "piraeus-operator"
	TargetBase         = "https://gitlab.at.linbit.com"
	TargetBranch       = "master"
	TargetProject      = "kubernetes/linstor-operator-builder"

	// Minimum number of approvals required for a PR from external people to be synced
	MinApprovalsForSync = 1
)

func main() {
	log.Level = logrus.DebugLevel

	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
	defer cancel()

	log.Info("setting up clients")

	gitlabToken := os.Getenv("GITLAB_TOKEN")

	// We only access public information on github
	ghClient := github.NewClient(nil)

	// For gitlab we need read and write permissions permissions
	glClient, err := gitlab.NewClient(gitlabToken, gitlab.WithBaseURL(TargetBase))
	if err != nil {
		log.WithField("err", err).Fatal("gitlab connection failed")
	}

	log.Info("fetch open pull requests")

	openSrcPulls, _, err := ghClient.PullRequests.List(ctx, SourceProjectOwner, SourceProjectRepo, nil)
	if err != nil {
		log.WithField("err", err).Fatal("failed to fetch source PRs")
	}

	destProject, _, err := glClient.Projects.GetProject(TargetProject, nil)
	if err != nil {
		log.WithField("err", err).Fatal("failed to get destination project")
	}

	log.Info("syncing all pull requests")

	for _, srcPull := range openSrcPulls {
		log := log.WithField("srcPull", srcPull)
		shouldSync, err := shouldSyncPull(ctx, ghClient, srcPull)
		if err != nil {
			log.WithField("err", err).Fatal("failed to check approval status of pull request")
		}

		if !shouldSync {
			log.Info("pull request does not meet sync criteria, skipping...")
			continue
		}

		err = syncPull(ctx, srcPull, destProject.ID, glClient)
		if err != nil {
			log.WithField("err", err).Fatal("failed to sync source pull")
		}
	}
}

func shouldSyncPull(ctx context.Context, client *github.Client, pull *github.PullRequest) (bool, error) {
	// "COLLABORATOR", "CONTRIBUTOR", "FIRST_TIMER", "FIRST_TIME_CONTRIBUTOR", "MEMBER", "OWNER", or "NONE"
	NoReviewRequired := []string{
		"COLLABORATOR",
		"MEMBER",
		"OWNER",
	}

	for _, assoc := range NoReviewRequired {
		if pull.GetAuthorAssociation() == assoc {
			return true, nil
		}
	}

	// Check for reviews. We only want to sync merge requests that have an up-to-date approval
	reviews, _, err := client.PullRequests.ListReviews(ctx, SourceProjectOwner, SourceProjectRepo, *pull.Number, nil)
	if err != nil {
		return false, err
	}

	upToDateAndApproved := 0
	for _, review := range reviews {
		if review.GetState() == "APPROVED" && review.GetCommitID() == pull.GetHead().GetSHA() {
			upToDateAndApproved += 1
		}
	}

	return upToDateAndApproved >= MinApprovalsForSync, nil
}

func syncPull(ctx context.Context, srcPull *github.PullRequest, destProjectID int, destClient *gitlab.Client) error {
	branchName := formatBranchName(*srcPull.Number)
	srcSHA := srcPull.GetHead().GetSHA()

	log := logrus.WithFields(logrus.Fields{
		"srcPull.ID": srcPull.ID,
		"branchName": branchName,
		"srcSHA":     srcSHA,
	})
	log.Info("syncing pull to branch")

	branch, resp, err := destClient.Branches.GetBranch(destProjectID, branchName, gitlab.WithContext(ctx))
	// 404 is expected here
	if err != nil && (resp == nil || resp.StatusCode != 404) {
		log.WithField("err", err).Info("failed to get branch")
		return err
	}

	if branch == nil {
		log.Info("new branch will be created")

		sourceBranch := "master"
		createdBranch, _, err := destClient.Branches.CreateBranch(destProjectID, &gitlab.CreateBranchOptions{
			Branch: &branchName,
			Ref:    &sourceBranch,
		}, gitlab.WithContext(ctx))
		if err != nil {
			log.WithField("err", err).Info("failed to create new branch")
			return err
		}
		branch = createdBranch
	}

	log.Info("check if submodule is up-to-date with upstream")

	file, _, err := destClient.RepositoryFiles.GetFile(destProjectID, SubprojectPath, &gitlab.GetFileOptions{
		Ref: &branchName,
	}, gitlab.WithContext(ctx))
	if err != nil {
		log.WithField("err", err).Info("failed to fetch submodule information")
		return err
	}

	if file.BlobID != srcSHA {
		log.Info("update submodule with newest commit from upstream")

		err := updateSubmodule(destClient, destProjectID, branchName, SubprojectPath, srcSHA, gitlab.WithContext(ctx))
		if err != nil {
			log.WithField("err", err).Info("failed to update submodule")
			return err
		}
	}

	log.Info("check if merge request exists")

	mrs, _, err := destClient.MergeRequests.ListProjectMergeRequests(destProjectID, &gitlab.ListProjectMergeRequestsOptions{
		SourceBranch: &branchName,
	}, gitlab.WithContext(ctx))
	if err != nil {
		log.WithField("err", err).Info("Failed to fetch merge requests")
		return err
	}

	if len(mrs) > 1 {
		log.WithField("mrs", mrs).Info("found more than 1 merge request")
		return err
	}

	if len(mrs) == 0 {
		log.Info("create new MR")

		title := "WIP: Upstream PR: " + *srcPull.Title
		description := formatDescription(srcPull)
		squash := true
		removeBranch := true
		allowCollab := true
		target := TargetBranch
		_, _, err := destClient.MergeRequests.CreateMergeRequest(destProjectID, &gitlab.CreateMergeRequestOptions{
			SourceBranch:       &branchName,
			TargetBranch:       &target,
			Labels:             &gitlab.Labels{"upstream"},
			Title:              &title,
			Description:        &description,
			Squash:             &squash,
			AllowCollaboration: &allowCollab,
			RemoveSourceBranch: &removeBranch,
		})
		if err != nil {
			log.WithField("err", err).Info("Failed to create merge request")
			return err
		}
	}

	return nil
}

// update an existing submodule by setting it to a given commit
// https://docs.gitlab.com/ee/api/repository_submodules.html
func updateSubmodule(client *gitlab.Client, pid int, branch, submodulePath, updateSha string, options ...gitlab.RequestOptionFunc) error {
	type SubmoduleOptions struct {
		Branch        *string `url:"branch,omitempty" json:"branch,omitempty"`
		CommitSHA     *string `url:"commit_sha,omitempty" json:"commit_sha,omitempty"`
		CommitMessage *string `url:"commit_message,omitempty" json:"commit_message,omitempty"`
	}
	msg := fmt.Sprintf("Sync %s with upstream pull request", SubprojectPath)
	path := fmt.Sprintf("/projects/%d/repository/submodules/%s", pid, url.PathEscape(submodulePath))

	// Note: Even though the commit is most likely part of different repository than the normal upstream (i.e. it's from
	// someones private fork), the commit is still accessible via the main repository:
	// > In other words, commits in a pull request are available in a repository even before the pull request is merged
	// src: https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/checking-out-pull-requests-locally#modifying-an-inactive-pull-request-locally
	req, err := client.NewRequest("PUT", path, &SubmoduleOptions{
		Branch:        &branch,
		CommitSHA:     &updateSha,
		CommitMessage: &msg,
	}, options)
	if err != nil {
		return err
	}

	_, err = client.Do(req, nil)
	return err
}

func formatBranchName(nr int) string {
	return fmt.Sprintf("piraeus-pull-%d", nr)
}

func formatDescription(upstream *github.PullRequest) string {
	const template = `# [Source](%s)

%s
`
	return fmt.Sprintf(template, *upstream.HTMLURL, *upstream.Body)
}
