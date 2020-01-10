variable "env" {
  default = "prod"
  type    = string
}
variable "sg_ports" {
  type    = list
  default = ["80", "443"]
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}
