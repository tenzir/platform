---
title: "Fix download links for Sovereign Edition platform"
type: bugfix
authors: lava
pr: 123
---
We switched to use the AWS v4 signature algorithm for generating presigned URLs,
rather than the deprecated v2 version. This fixes an incompatibility between
recent versions of boto3 and seaweedfs.
