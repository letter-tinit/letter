import SwiftUI
import UIKit
import Domain
import Utility
import Styleguide

public struct AudioFileShareSheet: UIViewControllerRepresentable {
    public let url: URL

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    public func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
