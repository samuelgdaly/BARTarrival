//
//  SystemView.swift
//  BARTArrivals
//
//  Created by Samuel Daly on 3/17/25.
//

import SwiftUI
import UIKit

struct SystemView: View {
    @State private var isAfter9PM = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Title - Using standard iOS navigation title size
            Text("System Map")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 44)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            
            // Map selector
            Picker("Schedule Time", selection: $isAfter9PM) {
                Text("Regular Service").tag(false)
                Text("After 9PM").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.white)
            
            // Map image view - Using available space with strict boundaries
            GeometryReader { geometry in
                ZStack {
                    BARTMapImageView(isAfter9PM: isAfter9PM, viewSize: geometry.size)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
    }
}

// BART Map Image View that displays the appropriate PNG image
struct BARTMapImageView: View {
    let isAfter9PM: Bool
    let viewSize: CGSize
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var position = CGSize.zero
    @State private var lastPosition = CGSize.zero
    
    var body: some View {
        ZStack {
            // Background container
            Color(.systemBackground)
            
            // Render the appropriate map image based on time of day
            Image(isAfter9PM ? "bart_map_night" : "bart_map_day")
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(x: position.width, y: position.height)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                // Ensure the scaled size never goes below screen dimensions
                                let newScale = scale * delta
                                let image = UIImage(named: isAfter9PM ? "bart_map_night" : "bart_map_day")
                                if let imageSize = image?.size {
                                    let minScale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
                                    scale = min(max(newScale, minScale), 4.0)
                                } else {
                                    scale = min(max(newScale, 1.0), 4.0)
                                }
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            },
                        DragGesture()
                            .onChanged { value in
                                let newPosition = CGSize(
                                    width: lastPosition.width + value.translation.width,
                                    height: lastPosition.height + value.translation.height
                                )
                                position = newPosition
                            }
                            .onEnded { _ in
                                lastPosition = position
                            }
                    )
                )
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring()) {
                                // Reset to minimum scale that ensures map fills screen
                                if let image = UIImage(named: isAfter9PM ? "bart_map_night" : "bart_map_day") {
                                    scale = max(viewSize.width / image.size.width, viewSize.height / image.size.height)
                                } else {
                                    scale = 1.0
                                }
                                position = .zero
                                lastPosition = .zero
                            }
                        }
                )
        }
    }
}

// Environment value for safe area insets
private struct SafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

struct SystemView_Previews: PreviewProvider {
    static var previews: some View {
        SystemView()
    }
} 