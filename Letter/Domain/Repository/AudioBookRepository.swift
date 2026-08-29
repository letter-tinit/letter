import Foundation

@MainActor
protocol AudioBookRepository: AnyObject {
    func speak(_ text: String)
    func pause()
    func resume()
    func stop()
}
