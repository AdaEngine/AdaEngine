#if os(Windows)
import Foundation
import WinSDK

/// An immutable kernel-object identity. Windows synchronizes job operations; Swift
/// ownership keeps the handle alive until the client/terminal has finished reaping.
final class EditorWindowsProcessTree: Sendable {
    private let address: UInt

    init(processIdentifier: Int32) throws {
        guard let job = CreateJobObjectW(nil, nil) else {
            throw EditorWindowsProcessError(message: "Unable to create a tool process job (\(GetLastError())).")
        }
        var limits = JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
        limits.BasicLimitInformation.LimitFlags = DWORD(JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE)
        let configured = SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, DWORD(MemoryLayout.size(ofValue: limits)))
        guard configured, let process = OpenProcess(DWORD(PROCESS_SET_QUOTA | PROCESS_TERMINATE), false, DWORD(processIdentifier)) else {
            CloseHandle(job)
            throw EditorWindowsProcessError(message: "Unable to supervise the tool process (\(GetLastError())).")
        }
        defer { CloseHandle(process) }
        guard AssignProcessToJobObject(job, process) else {
            CloseHandle(job)
            throw EditorWindowsProcessError(message: "Unable to supervise the tool process tree (\(GetLastError())).")
        }
        address = UInt(bitPattern: job)
    }

    func terminate() { TerminateJobObject(HANDLE(bitPattern: address), 1) }

    deinit { CloseHandle(HANDLE(bitPattern: address)) }
}
#endif
