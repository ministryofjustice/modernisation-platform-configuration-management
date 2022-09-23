variable "tags" {
  type        = map(string)
  description = "Common tags to be used by all resources"
}
variable "application_name" {
  type        = string
  description = "Name of application"
}
