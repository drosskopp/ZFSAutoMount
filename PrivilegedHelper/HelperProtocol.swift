import Foundation

@objc(HelperProtocol)
protocol HelperProtocol {
    func executeCommand(_ command: String, withReply reply: @escaping (String?, String?) -> Void)
}
