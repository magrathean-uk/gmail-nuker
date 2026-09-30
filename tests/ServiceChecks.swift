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
   let result=try await service.executeBlock(target:"large-output.test",commit:false)
   if !result.success {failed.append("large pipes")}
   else {print("PASS large stdout and stderr are drained without deadlock")}
  } catch {failed.append("large pipes")}
  if !failed.isEmpty {print("FAIL incorrectly accepted: \(failed.joined(separator:", "))");exit(1)}
 }
}
