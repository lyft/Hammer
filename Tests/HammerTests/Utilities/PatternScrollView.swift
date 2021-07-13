import Foundation
import UIKit

private let kCircleDiameter: CGFloat = 20

final class PatternScrollView: UIScrollView, UIScrollViewDelegate {
    init(contentSize: CGSize = .init(width: 1000, height: 1000)) {
        super.init(frame: .zero)
        self.contentInsetAdjustmentBehavior = .never
        self.maximumZoomScale = 10
        self.delegate = self

        let contentView = PatternView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: contentSize.width),
            contentView.heightAnchor.constraint(equalToConstant: contentSize.height),

            contentView.topAnchor.constraint(equalTo: self.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: self.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.contentLayoutGuide.trailingAnchor),
        ])
    }

    func addSubview(_ view: UIView, at rect: CGRect) {
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: rect.width),
            view.heightAnchor.constraint(equalToConstant: rect.height),

            view.leadingAnchor.constraint(equalTo: self.contentLayoutGuide.leadingAnchor,
                                          constant: rect.minX),
            view.topAnchor.constraint(equalTo: self.contentLayoutGuide.topAnchor,
                                      constant: rect.minY),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.subviews.first
    }
}

final class PatternView: UIView {
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return
        }

        ctx.setFillColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
        ctx.fill(rect)

        let size = CGSize(width: kCircleDiameter, height: kCircleDiameter)

        var currentY = kCircleDiameter / 2
        while currentY < rect.height {
            var currentX = kCircleDiameter / 2
            while currentX < rect.width {
                let point = CGPoint(x: currentX, y: currentY)
                ctx.strokeEllipse(in: CGRect(origin: point, size: size))

                currentX += kCircleDiameter * 2
            }

            currentY += kCircleDiameter * 2
        }
    }
}
