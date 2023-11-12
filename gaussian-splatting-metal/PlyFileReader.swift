//
//  PlyFileReader.swift
//  gaussian-splatting-metal
//
//  Created by Andry Rafaralahy on 28/10/2023.
//

import Foundation

class PlyFileReader {
    private var data: Data
    private var cursorPosition: Int
    var numVertices: Int?
    var currentVertice: Int?
    var propertyPosition: [String: Int]?

    init(_ path: URL) {
        do {
            data = try Data(contentsOf: path);
        } catch {
            fatalError(error.localizedDescription)
        }
        cursorPosition = 0
    }

    private func readLine() -> String {
        if cursorPosition >= data.count {
            fatalError("EOF")
        }
        var line: String = ""
        var char = Character(UnicodeScalar(data[cursorPosition].littleEndian))
        while char != "\n" {
            line.append(char)
            cursorPosition += 1
            if (cursorPosition >= data.count) {
                break;
            }
            char = Character(UnicodeScalar(data[cursorPosition].littleEndian))
        }
        cursorPosition += 1
        return line
    }

    func readHeader() {
        cursorPosition = 0
        var line = readLine()
        if (line != "ply") {
            fatalError("First line should be \"ply\", got \"" + line + "\"")
        }
        line = readLine()
        if (line != "format binary_little_endian 1.0") {
            fatalError("Second line should be \"format binary_little_endian 1.0\", got \"" + line + "\"")
        }
        line = readLine()
        let parts = line.split(separator: " ")
        if (parts[0] != "element") {
            fatalError("Expected element line, got \"" + line + "\"")
        }
        if (parts[1] != "vertex") {
            fatalError("Expected element type to be vertex, got " + parts[1])
        }
        guard let numVertices = Int(parts[2]) else {
            fatalError("Could not parse number of vertices: " + parts[2])
        }
        self.numVertices = numVertices

        readProperties()

        currentVertice = 0
    }

    private func readProperties() {
        propertyPosition = Dictionary()
        var pos = 0
        var line = readLine()
        while line != "end_header" {
            let parts = line.split(separator: " ")
            if (parts[0] != "property") {
                fatalError("Expected property line, got \"" + line + "\"")
            }
            if (parts[1] != "float") {
                fatalError("Expected type float, got \"" + parts[1] + "\"")
            }
            propertyPosition?[String(parts[2])] = pos;
            print(parts[1], parts[2])
            pos += 1
            line = readLine()
        }
    }

    func readGaussians() -> [Gaussian] {
        print("Num vertices \(numVertices!)")
        var gaussians: [Gaussian] = []
        for i in 0...(numVertices! - 1) {
//            if i >= 1048576 {
//                continue
//            }
//            if Float.random(in: 0..<1.0) > 0.01 {
//                continue
//            }
            if cursorPosition + MemoryLayout<Gaussian>.stride - 1 >= data.count {
                fatalError("Index out of bounds \(cursorPosition) >= \(data.count), \(i) vertices read")
            }
            let gaussian = data[cursorPosition...(cursorPosition + MemoryLayout<Gaussian>.stride - 1)].withUnsafeBytes { $0.load(as: Gaussian.self) }
            cursorPosition += MemoryLayout<Gaussian>.stride;
            gaussians.append(gaussian)
        }
        print("Num sampled vertices \(gaussians.count)")
        return gaussians
    }
}
