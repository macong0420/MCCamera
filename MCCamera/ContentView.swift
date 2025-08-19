//
//  ContentView.swift
//  MCCamera
//
//  Created by 马聪聪 on 2025/8/19.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        CameraView()
            .ignoresSafeArea()
            .onAppear {
                print("📱 ContentView onAppear - 应用启动完成")
            }
    }
}

#Preview {
    ContentView()
}
