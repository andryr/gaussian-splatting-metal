//
//  MetalView.swift
//  gaussian-splatting-metal
//
//  Created by Andry Rafaralahy on 11/11/2023.
//

import MetalKit
import SwiftUI

class MetalView : MTKView {
    private var onKeyUpCallback: ((NSEvent) -> Void)?
    private var onKeyDownCallback: ((NSEvent) -> Void)?
    private var onMouseDraggedCallback: ((NSEvent) -> Void)?
    
    override var acceptsFirstResponder: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        onKeyDownCallback?(event)
    }
    
    override func keyUp(with event: NSEvent) {
        onKeyUpCallback?(event)
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDraggedCallback?(event)
    }
    
    func onKeyDown(eventCallback: @escaping (NSEvent) -> Void) -> MetalView{
        onKeyDownCallback = eventCallback
        return self
    }
    
    func onKeyUp(eventCallback: @escaping (NSEvent) -> Void) -> MetalView {
        onKeyUpCallback = eventCallback
        return self
    }
    
    func onMouseDragged(eventCallback: @escaping (NSEvent) -> Void) -> MetalView {
        onMouseDraggedCallback = eventCallback
        return self
    }
}
