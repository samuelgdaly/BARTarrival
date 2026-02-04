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
            // Title - Large and left-justified
            Text("System Map")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 16)
                .padding(.bottom, 8)
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
            ZStack {
                BARTMapImageView(isAfter9PM: isAfter9PM)
            }
            .frame(maxHeight: .infinity)
            .clipped() // Important: prevent content from overflowing its container
        }
    }
}

// BART Map Image View that displays the appropriate PNG image
struct BARTMapImageView: View {
    let isAfter9PM: Bool
    // Set initial scale to fill the screen
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var position = CGSize.zero
    @State private var lastPosition = CGSize.zero
    
    // Environment to get safe area insets
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background container
                Color(.systemBackground)
                
                // Render the appropriate map image based on time of day
                mapImageView(named: isAfter9PM ? "bart_map_night" : "bart_map_day", geometry: geometry)
            }
            // Initialize map with proper sizing on appear
            .onAppear {
                // Calculate initial scale to fill the screen
                calculateInitialScale(for: geometry.size)
            }
        }
    }
    
    // Calculate initial scale to fill the screen
    private func calculateInitialScale(for size: CGSize) {
        // Initial position is centered
        position = CGSize.zero
        lastPosition = CGSize.zero
        
        // Initial scale is set to 1.0 (default) as the image will be sized to fill the frame
        scale = 1.0
    }
    
    private func mapImageView(named imageName: String, geometry: GeometryProxy) -> some View {
        // Get screen dimensions
        let screenSize = geometry.size
        
        // Calculate the tab bar height (approximate 49 points)
        let tabBarHeight: CGFloat = 49
        
        // Calculate available height accounting for the tab bar
        let availableHeight = screenSize.height - tabBarHeight
        
        return Image(imageName)
            .resizable()
            .scaledToFit() // Fit entire map on screen
            .scaleEffect(scale)
            .offset(x: position.width, y: position.height)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        // Allow zooming from 0.8 (slightly smaller than full) to 6.0 (highly detailed)
                        scale = min(max(scale * delta, 0.8), 6.0)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        // Apply the drag with looser constraints for better panning
                        let scaledWidth = screenSize.width * scale
                        let scaledHeight = availableHeight * scale
                        
                        // Determine how much of the image is outside the visible area
                        // For each dimension, if image is larger than view, allow scrolling proportional to overlap
                        let horizontalOverflow = max(0, scaledWidth - screenSize.width)
                        let verticalOverflow = max(0, scaledHeight - availableHeight)
                        
                        // Calculate the maximum allowed offsets in each direction
                        // Increased by 20% to allow smoother scrolling feel
                        let maxOffsetX = horizontalOverflow / 2 * 1.2
                        let maxOffsetY = verticalOverflow / 2 * 1.2
                        
                        // Calculate new position based on drag and existing position
                        let newWidth = lastPosition.width + value.translation.width
                        let newHeight = lastPosition.height + value.translation.height
                        
                        // Apply constraints with wider bounds for smoother panning
                        position = CGSize(
                            width: min(max(newWidth, -maxOffsetX), maxOffsetX),
                            height: min(max(newHeight, -maxOffsetY), maxOffsetY)
                        )
                    }
                    .onEnded { _ in
                        // Save position for next drag
                        lastPosition = position
                        
                        // If near the boundary, apply a bounce effect
                        withAnimation(.interactiveSpring()) {
                            // Calculate actual bounds for image size
                            let scaledWidth = screenSize.width * scale
                            let scaledHeight = availableHeight * scale
                            
                            let horizontalOverflow = max(0, scaledWidth - screenSize.width)
                            let verticalOverflow = max(0, scaledHeight - availableHeight)
                            
                            let maxHorizontalOffset = horizontalOverflow / 2
                            let maxVerticalOffset = verticalOverflow / 2
                            
                            // Only apply bounce if near or beyond boundaries
                            if abs(position.width) > maxHorizontalOffset {
                                position.width = position.width > 0 ? maxHorizontalOffset : -maxHorizontalOffset
                            }
                            
                            if abs(position.height) > maxVerticalOffset {
                                position.height = position.height > 0 ? maxVerticalOffset : -maxVerticalOffset
                            }
                            
                            // Update lastPosition after any bouncing
                            lastPosition = position
                        }
                    }
            )
            .onTapGesture(count: 2) {
                // Double tap to reset zoom to fill the screen
                withAnimation {
                    scale = 1.0
                    position = .zero
                    lastPosition = .zero
                }
            }
            // Use frame to fill the available space
            .frame(width: screenSize.width, height: availableHeight)
            .contentShape(Rectangle()) // Ensure gestures work on the whole area
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