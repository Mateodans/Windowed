import SwiftUI
import UIKit

struct GestureOverlayView: UIViewRepresentable {
    let onPinchOut: () -> Void
    let onPinchIn: () -> Void
    let onThreeFingerSwipeLeft: () -> Void
    let onThreeFingerSwipeRight: () -> Void
    let onFourFingerSwipeLeft: () -> Void
    let onFourFingerSwipeRight: () -> Void
    
    func makeUIView(context: Context) -> WindowGestureAttacherView {
        let view = WindowGestureAttacherView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: WindowGestureAttacherView, context: Context) {
        uiView.coordinator = context.coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPinchOut: onPinchOut,
            onPinchIn: onPinchIn,
            onThreeFingerSwipeLeft: onThreeFingerSwipeLeft,
            onThreeFingerSwipeRight: onThreeFingerSwipeRight,
            onFourFingerSwipeLeft: onFourFingerSwipeLeft,
            onFourFingerSwipeRight: onFourFingerSwipeRight
        )
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onPinchOut: () -> Void
        let onPinchIn: () -> Void
        let onThreeFingerSwipeLeft: () -> Void
        let onThreeFingerSwipeRight: () -> Void
        let onFourFingerSwipeLeft: () -> Void
        let onFourFingerSwipeRight: () -> Void
        
        private var pinchHandled = false
        private var threeFingerHandled = false
        private var fourFingerHandled = false
        
        init(
            onPinchOut: @escaping () -> Void,
            onPinchIn: @escaping () -> Void,
            onThreeFingerSwipeLeft: @escaping () -> Void,
            onThreeFingerSwipeRight: @escaping () -> Void,
            onFourFingerSwipeLeft: @escaping () -> Void,
            onFourFingerSwipeRight: @escaping () -> Void
        ) {
            self.onPinchOut = onPinchOut
            self.onPinchIn = onPinchIn
            self.onThreeFingerSwipeLeft = onThreeFingerSwipeLeft
            self.onThreeFingerSwipeRight = onThreeFingerSwipeRight
            self.onFourFingerSwipeLeft = onFourFingerSwipeLeft
            self.onFourFingerSwipeRight = onFourFingerSwipeRight
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                pinchHandled = false
            case .changed:
                if !pinchHandled {
                    if gesture.scale > 1.4 {
                        pinchHandled = true
                        onPinchOut()
                    } else if gesture.scale < 0.65 {
                        pinchHandled = true
                        onPinchIn()
                    }
                }
            case .ended, .cancelled:
                pinchHandled = false
            default:
                break
            }
        }
        
        @objc func handleThreeFingerPan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                threeFingerHandled = false
            case .ended:
                guard !threeFingerHandled else { return }
                threeFingerHandled = true
                
                let velocity = gesture.velocity(in: gesture.view)
                let translation = gesture.translation(in: gesture.view)
                
                if abs(velocity.x) > 300 || abs(translation.x) > 40 {
                    if velocity.x < 0 || translation.x < -40 {
                        onThreeFingerSwipeLeft()
                    } else if velocity.x > 0 || translation.x > 40 {
                        onThreeFingerSwipeRight()
                    }
                }
            case .cancelled, .failed:
                threeFingerHandled = false
            default:
                break
            }
        }
        
        @objc func handleFourFingerPan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                fourFingerHandled = false
            case .ended:
                guard !fourFingerHandled else { return }
                fourFingerHandled = true
                
                let velocity = gesture.velocity(in: gesture.view)
                let translation = gesture.translation(in: gesture.view)
                
                if abs(velocity.x) > 300 || abs(translation.x) > 40 {
                    if velocity.x < 0 || translation.x < -40 {
                        onFourFingerSwipeLeft()
                    } else if velocity.x > 0 || translation.x > 40 {
                        onFourFingerSwipeRight()
                    }
                }
            case .cancelled, .failed:
                fourFingerHandled = false
            default:
                break
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

class WindowGestureAttacherView: UIView {
    weak var coordinator: GestureOverlayView.Coordinator?
    private var pinchGesture: UIPinchGestureRecognizer?
    private var threeFingerPan: UIPanGestureRecognizer?
    private var fourFingerPan: UIPanGestureRecognizer?
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window = self.window, let coordinator = self.coordinator else { return }
        
        if let existingPinch = pinchGesture {
            window.removeGestureRecognizer(existingPinch)
        }
        if let existingThree = threeFingerPan {
            window.removeGestureRecognizer(existingThree)
        }
        if let existingFour = fourFingerPan {
            window.removeGestureRecognizer(existingFour)
        }
        
        let pinch = UIPinchGestureRecognizer(target: coordinator, action: #selector(GestureOverlayView.Coordinator.handlePinch(_:)))
        pinch.delegate = coordinator
        pinch.cancelsTouchesInView = false
        pinch.delaysTouchesBegan = false
        window.addGestureRecognizer(pinch)
        self.pinchGesture = pinch
        
        let threeFinger = UIPanGestureRecognizer(target: coordinator, action: #selector(GestureOverlayView.Coordinator.handleThreeFingerPan(_:)))
        threeFinger.minimumNumberOfTouches = 3
        threeFinger.maximumNumberOfTouches = 3
        threeFinger.delegate = coordinator
        threeFinger.cancelsTouchesInView = false
        threeFinger.delaysTouchesBegan = false
        window.addGestureRecognizer(threeFinger)
        self.threeFingerPan = threeFinger
        
        let fourFinger = UIPanGestureRecognizer(target: coordinator, action: #selector(GestureOverlayView.Coordinator.handleFourFingerPan(_:)))
        fourFinger.minimumNumberOfTouches = 4
        fourFinger.maximumNumberOfTouches = 4
        fourFinger.delegate = coordinator
        fourFinger.cancelsTouchesInView = false
        fourFinger.delaysTouchesBegan = false
        window.addGestureRecognizer(fourFinger)
        self.fourFingerPan = fourFinger
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

// Visual feedback overlay for gesture actions
struct GestureIndicatorView: View {
    let message: String
    let systemImage: String
    
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                Text(message)
                    .font(.headline)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { isVisible = false }
                }
            }
        }
    }
}
