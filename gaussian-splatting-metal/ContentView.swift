//
//  ContentView.swift
//  gaussian-splatting-metal
//
//  Created by Andry Rafaralahy on 11/10/2023.
//

import SwiftUI
import MetalKit


struct ContentView: NSViewRepresentable {
    typealias NSViewType = MetalView
    
    func makeCoordinator() -> Renderer {
        Renderer(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<ContentView>) -> MetalView {
        let mtkView = MetalView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        
        return mtkView
    }
    
    func updateNSView(_ uiView: MetalView, context: NSViewRepresentableContext<ContentView>) {
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
