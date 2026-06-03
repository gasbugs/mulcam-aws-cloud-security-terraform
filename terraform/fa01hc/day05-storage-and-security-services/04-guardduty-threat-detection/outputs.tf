output "detector_id" {
  description = "GuardDuty detector ID."
  value       = aws_guardduty_detector.main.id
}

output "ebs_malware_protection_status" {
  description = "GuardDuty EBS malware protection status."
  value       = aws_guardduty_detector_feature.ebs_malware_protection.status
}
