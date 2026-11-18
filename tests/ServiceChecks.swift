import Foundation
@main struct ServiceChecks {
 static func main() async {
  let service=BlockService(scriptPath:URL(fileURLWithPath:CommandLine.arguments[1]))
  var failed:[String]=[]
  for target in ["auth-failure.test","nonzero-success.test","stderr-failure.test"] {
   do { _ = try await service.executeBlock(target:target,commit:false);failed.append(target) }
   catch { print("PASS error is surfaced: \(target)") }
  }
  do {
   let result=try await service.executeBlock(target:"fixture.example",commit:false)
   if !result.success || result.committed != false || result.found_messages?.count != 1 {failed.append("success preview")}
   else { print("PASS synthetic preview decodes") }
  } catch {failed.append("success preview")}
  do {
   let preview=try await service.executeBlock(target:"fixture.example",commit:false)
   let deletion=try await service.deletePrevious(result:preview)
   if deletion.error != nil || deletion.deleted_permanently != 1 || deletion.delete_verified != true {failed.append("selected permanent delete")}
   else {print("PASS selected preview IDs are permanently deleted and verified")}
  } catch {failed.append("selected permanent delete")}
  do {
   let preview=try await service.executeBlock(target:"unverified-delete.test",commit:false)
   _ = try await service.deletePrevious(result:preview)
   failed.append("unverified delete")
  } catch {print("PASS unverified deletion is rejected")}
  do {
   let preview=try await service.executeBlock(target:"multi.example",commit:false)
   let deletion=try await service.deletePrevious(result:preview)
   if preview.total != 3 || !preview.truncated || preview.found_messages?.count != 1 {failed.append("whole-history decode")}
   else if deletion.deleted_permanently != 3 {failed.append("whole-history delete uses found_ids")}
   else {print("PASS whole-history IDs (found_ids, total, truncation) decode and are all deleted")}
  } catch {failed.append("whole-history delete")}
  do {
   let preview=try await service.executeBlock(target:"legacy.example",commit:false)
   let deletion=try await service.deletePrevious(result:preview)
   if preview.found_ids != nil || deletion.deleted_permanently != 1 {failed.append("legacy fallback")}
   else {print("PASS missing found_ids falls back to preview IDs")}
  } catch {failed.append("legacy fallback")}
  do {
   let blocked=try await service.listBlocked()
   let offenders=try await service.offenders(days:30)
   if blocked.count != 1 || blocked[0].filter_id != "filter-1" || offenders.count != 1 || offenders[0].count != 4 || !offenders[0].has_unsubscribe {failed.append("list decode")}
   else {print("PASS blocked list and offenders decode")}
  } catch {failed.append("list decode")}
  do {
   try await service.unblock(filterId:"filter-1")
   print("PASS verified unblock accepted")
  } catch {failed.append("unblock")}
  do {
   try await service.unblock(filterId:"unverified-filter")
   failed.append("unverified unblock")
  } catch {print("PASS unverified unblock is rejected")}
  do {
   let result=try await service.executeBlock(target:"large-output.test",commit:false)
   if !result.success {failed.append("large pipes")}
   else {print("PASS large stdout and stderr are drained without deadlock")}
  } catch {failed.append("large pipes")}
  if !failed.isEmpty {print("FAIL incorrectly accepted: \(failed.joined(separator:", "))");exit(1)}
 }
}
