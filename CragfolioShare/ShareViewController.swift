import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let message = UILabel()
        message.translatesAutoresizingMaskIntoConstraints = false
        message.numberOfLines = 0
        message.textAlignment = .center
        message.text = "Cragfolio share intake is not available in this foundation build. No items were saved."
        view.addSubview(message)

        NSLayoutConstraint.activate([
            message.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            message.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            message.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
