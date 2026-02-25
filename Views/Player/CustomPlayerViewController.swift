import AVFoundation
import AVKit
import UIKit

final class CustomPlayerViewController: UIViewController, AVPictureInPictureControllerDelegate {
    private var playerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?
    private var subtitleLabel: UILabel?
    private var subtitleBgView: UIView?
    private var subtitleImageView: UIImageView?

    func configure(player: AVPlayer) {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        self.playerLayer = layer

        // Subtitle text overlay
        let bgView = UIView()
        bgView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        bgView.layer.cornerRadius = 4
        bgView.isHidden = true
        bgView.isUserInteractionEnabled = false
        bgView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowRadius = 4
        label.layer.shadowOpacity = 1.0
        label.isHidden = true
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bgView)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            bgView.topAnchor.constraint(equalTo: label.topAnchor, constant: -8),
            bgView.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            bgView.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: -12),
            bgView.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12)
        ])

        self.subtitleLabel = label
        self.subtitleBgView = bgView

        // PGS bitmap subtitle overlay
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.isHidden = true
        imageView.isUserInteractionEnabled = false
        imageView.layer.magnificationFilter = .trilinear
        imageView.layer.minificationFilter = .trilinear
        view.addSubview(imageView)
        self.subtitleImageView = imageView

        // PiP
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: layer)
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
            pipController?.delegate = self
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    func updateSubtitleText(_ text: String?) {
        if let text {
            subtitleLabel?.text = text
            subtitleLabel?.isHidden = false
            subtitleBgView?.isHidden = false
        } else {
            subtitleLabel?.isHidden = true
            subtitleBgView?.isHidden = true
        }
    }

    func updateSubtitleImage(_ image: UIImage?, frame: CGRect) {
        guard let imageView = subtitleImageView else { return }
        guard let image else {
            imageView.isHidden = true
            return
        }

        guard let videoRect = playerLayer?.videoRect,
              videoRect.width > 0, videoRect.height > 0 else {
            imageView.isHidden = true
            return
        }

        imageView.image = image
        let finalFrame = CGRect(
            x: videoRect.origin.x + frame.origin.x * videoRect.width,
            y: videoRect.origin.y + frame.origin.y * videoRect.height,
            width: frame.width * videoRect.width,
            height: frame.height * videoRect.height
        )
        imageView.frame = finalFrame
        imageView.isHidden = false
    }
}
