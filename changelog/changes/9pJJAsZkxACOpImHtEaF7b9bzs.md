---
title: "Various UI Improvements"
type: bugfix
authors: gitryder, dit7ya
---
This release also contains many additional bugfixes and improvements to the Tenzir UI:

* Fixed an issue that prevented cookie deletion.
* Improved error logging for OpenID configuration decoding failures.
* Fixed a bug where column resizing would break when new data with the same schema arrived.
* Big numbers are now handled precisely in the data table and inspector.
* A toast message is now displayed while the data download is being prepared.
* Fixed a bug that caused the page to freeze when clicking outside the pipeline editor during editing.
* The timestamp displayed in the tooltip of ingress/egress charts was fixed.
