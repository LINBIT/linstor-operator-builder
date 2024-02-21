addEventListener("DOMContentLoaded", (event) => {
    let kubectlInstructions = document.getElementById("kubectl-instructions");
    let releases = document.getElementById("releases");

    fetch("./content/releases.json")
        .then((resp) => {
            return resp.json();
        })
        .then((content) => {
            let first = content[0];
            kubectlInstructions.innerHTML = kubectlInstructions.innerHTML.replace("https://charts.linstor.io/static/latest.yaml", `https://charts.linstor.io/static/v${first.version}.yaml`);
            let release_cards = content.map((v) => {
                let card = document.createElement("aside");
                card.innerHTML = `
                    <h3>${v.version}</h3>
                    <p><a href="static/v${v.version}.yaml">Manifest</a></p>
                    <p><a href="static/v${v.version}.image-list.txt">Image List</a></p>
                    <p><a href="linstor-operator-${v.version}.tgz">Chart</a></p>
                `;
                return card;
            });

            for (let card of release_cards) {
                releases.appendChild(card);
            }
        });
});
