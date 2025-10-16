import Foundation
import ServiceManagement

class PrivilegedHelperManager {
    static let shared = PrivilegedHelperManager()

    private let helperID = "org.openzfs.automount.helper"
    private var xpcConnection: NSXPCConnection?

    private init() {}

    // MARK: - Helper Installation

    func installHelper(completion: @escaping (Bool, String?) -> Void) {
        var authRef: AuthorizationRef?
        var authItem = kSMRightBlessPrivilegedHelper.withCString { authorizationString in
            AuthorizationItem(name: authorizationString, valueLength: 0, value: nil, flags: 0)
        }
        var authRights = withUnsafeMutablePointer(to: &authItem) { pointer in
            AuthorizationRights(count: 1, items: pointer)
        }

        let status = AuthorizationCreate(&authRights, nil, [.interactionAllowed, .extendRights, .preAuthorize], &authRef)

        guard status == errAuthorizationSuccess else {
            completion(false, "Failed to create authorization: \(status)")
            return
        }

        defer {
            if let authRef = authRef {
                AuthorizationFree(authRef, [])
            }
        }

        var error: Unmanaged<CFError>?
        let result = SMJobBless(kSMDomainSystemLaunchd, helperID as CFString, authRef, &error)

        if result {
            completion(true, nil)
        } else {
            let err = error?.takeRetainedValue()
            completion(false, err?.localizedDescription ?? "Unknown error")
        }
    }

    func isHelperInstalled() -> Bool {
        // Check if helper is registered
        guard let jobs = SMCopyAllJobDictionaries(kSMDomainSystemLaunchd).takeRetainedValue() as? [[String: Any]] else {
            return false
        }

        return jobs.contains { $0["Label"] as? String == helperID }
    }

    // MARK: - XPC Communication

    private func getConnection() -> NSXPCConnection {
        if let connection = xpcConnection {
            return connection
        }

        let connection = NSXPCConnection(machServiceName: helperID, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.invalidationHandler = {
            self.xpcConnection = nil
        }
        connection.interruptionHandler = {
            self.xpcConnection = nil
        }
        connection.resume()

        xpcConnection = connection
        return connection
    }

    // MARK: - Execute Commands

    func executeCommand(command: String, completion: @escaping (Bool, String?, String?) -> Void) {
        if !isHelperInstalled() {
            installHelper { success, error in
                if !success {
                    completion(false, nil, error)
                    return
                }
                self.executeCommand(command: command, completion: completion)
            }
            return
        }

        let connection = getConnection()
        guard let helper = connection.remoteObjectProxyWithErrorHandler({ error in
            completion(false, nil, error.localizedDescription)
        }) as? HelperProtocol else {
            completion(false, nil, "Failed to get helper proxy")
            return
        }

        helper.executeCommand(command) { output, error in
            completion(error == nil, output, error)
        }
    }

    func loadKey(for dataset: String, key: String, keyFormat: String, completion: @escaping (Bool, String?) -> Void) {
        let command = "load_key:\(dataset):\(keyFormat):\(key)"
        executeCommand(command: command) { success, output, error in
            completion(success, error)
        }
    }
}
