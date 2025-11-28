//
//  PullEffectScrollView.swift
//  Ora
//
//  Created by Nick Rogers on 11/28/25.
//


import FirebaseFirestore
import MapKit
import SwiftUI
//import Lottie

struct PullEffectScrollView<Content: View>: View {
    var dragDistance: CGFloat = 100
    var actionTopPadding: CGFloat = 0
    var leadingAction: PullEffectAction
    var centerAction: PullEffectAction
    var trailingAction: PullEffectAction
    @ViewBuilder var content: Content

    @State private var effectProgress: CGFloat = 0
    @GestureState private var isGestureActive: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var initialScroll0ffset: CGFloat?
    @State private var activePosition: ActionPosition?
    @State private var hapticsTrigger: Bool = false
    @State private var scaleEffect: Bool = false
    @Namespace private var animation

    var body: some View {
        ScrollView(.vertical) {
            content
        }
        .onScrollGeometryChange(
            for: CGFloat.self,
            of: {
                $0.contentOffset.y + $0.contentInsets.top
            },
            action: { oldValue, newValue in
                scrollOffset = newValue
            }
        )
        .onChange(of: isGestureActive) { oldValue, newValue in
            initialScroll0ffset = newValue ? scrollOffset.rounded() : nil
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating(
                    $isGestureActive,
                    body: { _, out, _ in
                        out = true
                    }
                )
                .onChanged { value in
                    guard initialScroll0ffset == 0 else { return }

                    let translationY = value.translation.height
                    let progress = min(max(translationY / dragDistance, 0), 1)
                    effectProgress = progress

                    guard translationY >= dragDistance else {
                        activePosition = nil
                        return
                    }
                    let translationX = value.translation.width
                    let indexProgress = translationX / dragDistance
                    let index: Int =
                        -indexProgress > 0.5
                        ? -1 : (indexProgress > 0.5 ? 1 : 0)
                    let landingAction = ActionPosition.allCases.first(where: {
                        $0.rawValue == index
                    })

                    if activePosition != landingAction {
                        hapticsTrigger.toggle()
                    }

                    activePosition = landingAction
                }
                .onEnded { value in
                    guard effectProgress != 0 else { return }
                    if let activePosition {
                        withAnimation(
                            .easeInOut(duration: 0.25),
                            completionCriteria:
                                .logicallyComplete
                        ) {
                            scaleEffect = true
                        } completion: {
                            scaleEffect = false
                            effectProgress = 0
                            self.activePosition = nil
                        }
                        switch activePosition {
                        case .leading: trailingAction.action()
                        case .center: centerAction.action()
                        case .trailing: trailingAction.action()
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            effectProgress = 0
                        }
                    }
                },
            isEnabled: !scaleEffect
        )
        .overlay(alignment: .top) {
            ActionsView()
                .padding(.top, actionTopPadding * 2)

        }
        .sensoryFeedback(.impact, trigger: hapticsTrigger)
    }

    /// Actions View
    @ViewBuilder private func ActionsView() -> some View {
        HStack(spacing: 0) {
            let delayedProgress = (effectProgress - 0.7) / 0.3

            ActionButton(.leading)
                .offset(x: 30 * (1 - delayedProgress))
                .opacity(delayedProgress)

            ActionButton(.center)
                .blur(radius: 10 * (1 - effectProgress))
                .opacity(effectProgress)
            ActionButton(.trailing)
                .offset(x: -30 * (1 - delayedProgress))
                .opacity(delayedProgress)
        }
        .padding(.horizontal, 20)
        .opacity(scaleEffect ? 0 : 1)
    }
    /// Action Button
    @ViewBuilder
    private func ActionButton(_ position: ActionPosition) -> some View {
        let action =
            position == .center
            ? centerAction
            : position == .trailing ? trailingAction : leadingAction
        Image(action.symbol)
            .foregroundStyle(.white)
            .opacity(scaleEffect ? 0 : 1)
            .animation(.linear(duration: 0.05), value: scaleEffect)
            .padding(.horizontal)
            .frame(height: 40)
            .background {
                if activePosition == position {
                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.1))
                        Rectangle()
                            .fill(.black.opacity(0.1))
                    }
                    .clipShape(.rect(cornerRadius: scaleEffect ? 0 : 30))
                    .compositingGroup()
                    .matchedGeometryEffect(id: "INDICATOR", in: animation)
                    .scaleEffect(scaleEffect ? 20 : 1, anchor: .bottom)
                }
            }
            .frame(maxWidth: .infinity)
            .compositingGroup()
            .animation(.easeInOut(duration: 0.25), value: activePosition)
    }

    private enum ActionPosition: Int, CaseIterable {
        case leading = -1
        case center = 0
        case trailing = 1
    }
}



struct PullEffectAction {
    var symbol: String
    var action: () -> Void
}

// Building Custom ScrollView Using View Builder
struct CustomScrollView<Content: View>: View {
    // To hold our view or to capture the described view
    var content: Content
    @Binding var offset: CGPoint
    @State var startOffset: CGPoint = .zero
    var showIndicators: Bool
    var axis: Axis.Set
    // Since it will carry multiple views
    // so it will be a closure and it will return view
    init(
        offset: Binding<CGPoint>,
        showIndicators: Bool,
        axis: Axis.Set,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self._offset = offset
        self.showIndicators = showIndicators
        self.axis = axis
    }

    var body: some View {
        ScrollView(
            axis,
            showsIndicators: showIndicators,
            content: {
                content
                    .overlay(
                        // Using Geometry reader to get offset
                        GeometryReader { proxy -> Color in
                            let rect = proxy.frame(in: .global)
                            if self.startOffset == .zero {
                                DispatchQueue.main.async {
                                    self.startOffset = CGPoint(
                                        x: rect.minX,
                                        y: rect.minY
                                    )
                                }
                            }
                            DispatchQueue.main.async {
                                // Minus from current
                                self.offset = CGPoint(
                                    x: startOffset.x - rect.minX,
                                    y: startOffset.y - rect.minY
                                )
                            }
                            return Color.clear
                        }
                        // Since we're also fetching horizontal offset
                        // so setting width to full so that minX will be zero
                        .frame(width: UIScreen.main.bounds.width, height: 0)

                        ,
                        alignment: .top
                    )
            }
        )
    }
}
