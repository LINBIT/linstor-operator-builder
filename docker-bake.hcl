variable "REGISTRY" {
  default = ""
}

variable "PLATFORMS" {
  default = "linux/amd64"
}

variable "TAG" {
  default = "latest"
}

variable GOPROXY {
  default = ""
}

variable VERSION {
  default = ""
}

group "default" {
  targets = [
    "linstor-operator"
  ]
}

function "escape" {
  params = [string]
  result = "${regex_replace(string, "[^a-zA-Z0-9_-]", "-")}"
}

function "platform_variants" {
  params = [platforms]
  result = concat([
    {
      prefix = ""
      platforms = split(",", platforms)
    }
  ], [
    for plat in split(",", platforms) :
    {
      prefix = "${trimprefix(plat, "linux/")}/"
      platforms = [plat]
    }
  ])
}

target "linstor-operator" {
  name = "${escape(platforms.prefix)}linstor-operator"
  tags = [
    "${REGISTRY}/${platforms.prefix}linstor-operator:${TAG}"
  ]
  matrix = {
    platforms = platform_variants(PLATFORMS)
  }
  args = {
    GOPROXY = GOPROXY
    VERSION = VERSION
  }
  context   = "."
  platforms = platforms.platforms
}
