# Copyright 2023 Teak.io, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "tags" {
  type        = map(string)
  default     = null
  description = "Additional tags to attach the created IAM policies."
}

variable "config_bucket_id" {
  type        = string
  default     = null
  description = "The ID of the S3 bucket backup configuration is stored in."
}

variable "log_access_policy_name" {
  type        = string
  default     = "LogAccess"
  description = "The name to assign to the IAM policy which permits logging access."
}

variable "config_access_policy_name" {
  type        = string
  default     = "ConfigAccess"
  description = "The name to assign to the IAM policy which permits configuration access."
}
