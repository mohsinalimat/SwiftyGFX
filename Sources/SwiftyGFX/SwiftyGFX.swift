import CFreeType
import Foundation
#if os(macOS) || os(iOS)
import Darwin
#elseif os(Linux) || CYGWIN
import Glibc
#endif


public struct Point: Equatable, CustomStringConvertible {
    
    public var x: Int
    public var y: Int
    
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    public static func ==(lhs: Point, rhs: Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
    
    public var description: String {
        return "\(x)\t\(y)"
    }
    
    public var coordinates: (Int, Int) {
        return (x, y)
    }
    
}

fileprivate extension Array where Element == Point {
    
    func movedTo(_ point: Point) -> [Point] {
        return self.map({ return Point(x: $0.x+point.x, y: $0.y+point.y)})
    }
    
    func convertedToCoordinates() -> [(Int, Int)] {
        return self.map({ $0.coordinates })
    }
}

public protocol Drawable {
    var origin: Point { get set }
    func generatePointsForDrawing() -> [(Int, Int)]
}

public protocol Fillable {
    associatedtype T
    mutating func fill()
    func filled() -> T
}

//Using Bresenham's line algorithm
internal func pointsForLine(from p1: Point, to p2: Point) -> [Point] {
    
    guard p1.x != p2.x && p1.y != p2.y else { return [p1] }
    
    let Δx = p1.x - p2.x
    let Δy = p1.y - p2.y
    
    //α to nachylenie
    let αx = Δx < 0 ? 1 : -1
    let αy = Δy < 0 ? 1 : -1
    
    var result = [Point]()
    
    if abs(Δy) < abs(Δx) {
        let α = Double(Δy) / Double(Δx)
        let pitch = Double(p1.y) - α * Double(p1.x) //to wysokość
        var p1 = p1
        while p1.x != p2.x {
            result.append(Point(x: p1.x, y: Int((α * Double(p1.x) + pitch).rounded())))
            p1.x += αx
        }
    } else {
        let α = Double(Δx) / Double(Δy)
        let pitch = Double(p1.x) - α * Double(p1.y)
        var p1 = p1
        while p1.y != p2.y {
            result.append(Point(x: Int((α * Double(p1.y) + pitch).rounded()), y: p1.y))
            p1.y += αy
        }
    }
    
    result.append(p2)
    return result
}

internal func pointsForVerticalLine(from p1: Point, to p2: Point) -> [Point] {
    
    var result = [Point]()
    result.reserveCapacity(abs(p2.y-p1.y))
    
    for y in stride(from: p1.y, through: p2.y, by: p1.y > p2.y ? -1 : 1) {
        result.append(Point(x: p1.x, y: y))
    }
    
    return result
    
}

internal func pointsForHorizontalLine(from p1: Point, to p2: Point) -> [Point] {
    
    var result = [Point]()
    result.reserveCapacity(abs(p2.x-p1.x))
    
    for x in stride(from: p1.x, through: p2.x, by: p1.x > p2.x ? -1 : 1) {
        result.append(Point(x: x, y: p1.y))
    }
    
    return result
    
}

//Lines
public struct ObliqueLine: Drawable {
    public var origin: Point
    public var endPoint: Point
    
    init(from origin: Point, to endPoint: Point) {
        self.endPoint = endPoint
        self.origin = origin
    }
    
    public func generatePointsForDrawing() -> [(Int, Int)] {
        return pointsForLine(from: origin, to: endPoint).convertedToCoordinates()
    }
    
}
public struct HorizontalLine: Drawable {
    
    public var origin: Point
    public var endPoint: Point
    
    init(from origin: Point, to endPoint: Point) {
        self.origin = origin
        self.endPoint = endPoint
    }
    
    init(from origin: Point, lenght: UInt) {
        self.origin = origin
        self.endPoint = Point(x: origin.x+Int(lenght), y: origin.y)
    }
    
    public func generatePointsForDrawing() -> [(Int, Int)] {
        return pointsForHorizontalLine(from: origin, to: Point(x: endPoint.x, y: origin.y)).convertedToCoordinates()
    }
    
}
public struct VerticalLine: Drawable {
    
    public var origin: Point
    public var endPoint: Point
    
    init(from origin: Point, to endPoint: Point) {
        self.origin = origin
        self.endPoint = endPoint
    }
    
    init(from origin: Point, lenght: UInt) {
        self.origin = origin
        self.endPoint = Point(x: origin.x, y: origin.y+Int(lenght))
    }
    
    public func generatePointsForDrawing() -> [(Int, Int)] {
        return pointsForVerticalLine(from: origin, to: Point(x: origin.x, y: endPoint.y)).convertedToCoordinates()
    }
    
}

//Rectangles
public struct Rectangle: Drawable, Fillable {
    
    public var origin: Point
    public private(set) var isFilled = false
    public var width: UInt
    public var height: UInt
    
    init(at origin: Point = Point(x: 0, y: 0), height: UInt, width: UInt) {
        self.origin = origin
        self.height = height
        self.width = width
    }
    
    mutating public func fill() {
        self.isFilled = true
    }
    
    public func filled() -> Rectangle {
        var result = self
        result.isFilled = true
        return self
    }
    
    public func generatePointsForDrawing() -> [(Int, Int)] {
        var result = [Point]()
        
        switch isFilled {
        case true:
            for i in 0...Int(height)-1 {
                    result.append(contentsOf: pointsForHorizontalLine(from: Point(x: 0, y: i), to: Point(x: Int(width)-1, y: i)))
            }
        case false:
            result.append(contentsOf: pointsForVerticalLine(from: Point(x: 0, y: 0), to: Point(x: Int(width), y: 0)))
            result.append(contentsOf: pointsForHorizontalLine(from: Point(x: Int(width), y: 0), to: Point(x: Int(width), y: Int(height))))
            result.append(contentsOf: pointsForVerticalLine(from: Point(x: Int(width), y: Int(height)), to: Point(x: 0, y: Int(width))))
            result.append(contentsOf: pointsForHorizontalLine(from: Point(x: 0, y: Int(width)), to: Point(x: 0, y: 0)))
        }
        
        return result.movedTo(origin).convertedToCoordinates()
    }

}
public struct Square: Drawable, Fillable {
    
    public var origin: Point
    public private(set) var isFilled = false
    public var sideSize: UInt
    
    
    init(at origin: Point = Point(x: 0, y: 0), sideSize a: UInt) {
        self.origin = origin
        self.sideSize = a
    }
    
    mutating public func fill() {
        self.isFilled = true
    }
    
    public func filled() -> Square {
        var result = self
        result.isFilled = true
        return self
    }
    
    public func generatePointsForDrawing() -> [(Int, Int)] {
        var result = [Point]()
        
        switch isFilled {
        case true:
            for i in 0...Int(sideSize)-1 {
                result.append(contentsOf: pointsForHorizontalLine(from: Point(x: 0, y: i), to: Point(x: Int(sideSize)-1, y: i)))
            }
        case false:
            result.append(contentsOf: pointsForVerticalLine(from: Point(x: 0, y: 0), to: Point(x: Int(sideSize), y: 0)))
            result.append(contentsOf: pointsForHorizontalLine(from: Point(x: Int(sideSize), y: 0), to: Point(x: Int(sideSize), y: Int(sideSize))))
            result.append(contentsOf: pointsForVerticalLine(from: Point(x: Int(sideSize), y: Int(sideSize)), to: Point(x: 0, y: Int(sideSize))))
            result.append(contentsOf: pointsForHorizontalLine(from: Point(x: 0, y: Int(sideSize)), to: Point(x: 0, y: 0)))
        }
        
        return result.movedTo(origin).convertedToCoordinates()
    }

}

//Ellipses
public struct Ellipse: Drawable, Fillable {
    
    public var origin: Point
    public private(set) var isFilled = false
    public var yRadius: UInt
    public var xRadius: UInt
    
    init(at origin: Point = Point(x: 0, y: 0), yRadius: UInt, xRadius: UInt) {
        self.origin = origin
        self.yRadius = yRadius
        self.xRadius = xRadius
    }

    init(at origin: Point = Point(x: 0, y: 0), height: UInt, width: UInt) {
        self.origin = origin
        self.yRadius = height/2
        self.xRadius = width/2
    }
    
    mutating public func fill() {
        self.isFilled = true
    }
    
    public func filled() -> Ellipse {
        var result = self
        result.isFilled = true
        return result
    }
    
    public func generatePointsForDrawing() -> [(Int, Int)] {
        
        var result = [Point]()
        
        switch isFilled {
        case true:
            
            for x in stride(from: -Int(xRadius), through: Int(xRadius), by: 1) {
                result.append(Point(x: x + Int(xRadius), y: Int(yRadius)))
            }
            
            var x0 = Int(xRadius)
            var dx = 0
            
            // now do both halves at the same time, away from the diameter
            for y in stride(from: 1, through: Int(yRadius), by: 1) {
                var x1 = x0 - (dx - 1);  // try slopes of dx - 1 or more
                
                while x1 > 0 {
                    if x1*x1*Int(yRadius)*Int(yRadius) + y*y*Int(xRadius)*Int(xRadius) <= Int(yRadius)*Int(yRadius)*Int(xRadius)*Int(xRadius) { break }
                    x1 -= 1
                }
                
                dx = x0 - x1;  // current approximation of the slope
                x0 = x1;
                
                for x in stride(from: -x0, through: x0, by: 1) {
                    result.append(Point(x: x + Int(xRadius), y: -y + Int(yRadius)))
                    result.append(Point(x: x + Int(xRadius), y: y + Int(yRadius)))
                }
                
            }
        case false:
            
            result.append(Point(x: 0, y: Int(yRadius)))
            result.append(Point(x: 2 * Int(xRadius), y: Int(yRadius)))
            
            var x0 = Int(xRadius)
            var dx = 0
            
            // now do both halves at the same time, away from the diameter
            for y in stride(from: 1, through: Int(yRadius), by: 1) {
                var x1 = x0 - (dx - 1);  // try slopes of dx - 1 or more
                
                while x1 > 0 {
                    if x1*x1*Int(yRadius)*Int(yRadius) + y*y*Int(xRadius)*Int(xRadius) <= Int(yRadius)*Int(yRadius)*Int(xRadius)*Int(xRadius) { break }
                    x1 -= 1
                }
                
                dx = x0 - x1;  // current approximation of the slope
                x0 = x1;
                
                result.append(Point(x: -x0 + Int(xRadius), y: y + Int(yRadius)))
                result.append(Point(x: -x0 + Int(xRadius), y: -y + Int(yRadius)))
                result.append(Point(x: x0 + Int(xRadius), y: y + Int(yRadius)))
                result.append(Point(x: x0 + Int(xRadius), y: -y + Int(yRadius)))
            }
        }
        return result.movedTo(origin).convertedToCoordinates()
    }
    
}
public struct Circle: Drawable, Fillable {
    
    public var origin: Point
    public private(set) var isFilled = false
    public var radius: UInt
    
    init(at origin: Point = Point(x: 0, y: 0), radius: UInt) {
        self.origin = origin
        self.radius = radius
    }
    
    init(at origin: Point = Point(x: 0, y: 0), width: UInt) {
        self.origin = origin
        self.radius = width/2
    }
    
    mutating public func fill() {
        self.isFilled = true
    }
    
    public func filled() -> Circle {
        var result = self
        result.isFilled = true
        return result
    }
    
    public func generatePointsForDrawing() -> [(Int, Int)] {
        
        var result = [Point]()
        
        switch isFilled {
        case true:
            
            for x in stride(from: -Int(radius), through: Int(radius), by: 1) {
                result.append(Point(x: x + Int(radius), y: Int(radius)))
            }
            
            var x0 = Int(radius)
            var dx = 0
            
            // now do both halves at the same time, away from the diameter
            for y in stride(from: 1, through: Int(radius), by: 1) {
                var x1 = x0 - (dx - 1);  // try slopes of dx - 1 or more
                
                while x1 > 0 {
                    if x1*x1*Int(radius)*Int(radius) + y*y*Int(radius)*Int(radius) <= Int(radius)*Int(radius)*Int(radius)*Int(radius) { break }
                    x1 -= 1
                }
                
                dx = x0 - x1;  // current approximation of the slope
                x0 = x1;
                
                for x in stride(from: -x0, through: x0, by: 1) {
                    result.append(Point(x: x + Int(radius), y: -y + Int(radius)))
                    result.append(Point(x: x + Int(radius), y: y + Int(radius)))
                }
                
            }
        case false:
            
            result.append(Point(x: 0, y: Int(radius)))
            result.append(Point(x: 2 * Int(radius), y: Int(radius)))
            
            var x0 = Int(radius)
            var dx = 0
            
            // now do both halves at the same time, away from the diameter
            for y in stride(from: 1, through: Int(radius), by: 1) {
                var x1 = x0 - (dx - 1);  // try slopes of dx - 1 or more
                
                while x1 > 0 {
                    if x1*x1*Int(radius)*Int(radius) + y*y*Int(radius)*Int(radius) <= Int(radius)*Int(radius)*Int(radius)*Int(radius) { break }
                    x1 -= 1
                }
                
                dx = x0 - x1;  // current approximation of the slope
                x0 = x1;
                
                result.append(Point(x: -x0 + Int(radius),y: y + Int(radius)))
                result.append(Point(x: -x0 + Int(radius),y: -y + Int(radius)))
                result.append(Point(x: x0 + Int(radius),y: y + Int(radius)))
                result.append(Point(x: x0 + Int(radius),y: -y + Int(radius)))
            }
        }
        return result.movedTo(origin).convertedToCoordinates()
    }
    
}

//Traingels
public struct Triangle: Drawable, Fillable {
    
    public var origin: Point
    public var p1: Point
    public var p2: Point
    public var p3: Point
    public private(set) var isFilled = false
    
    init(at origin: Point = Point(x: 0, y: 0), corner1: Point, corner2: Point, corner3: Point) {
        self.origin = origin
        self.p1 = corner1
        self.p2 = corner2
        self.p3 = corner3
    }
    
    mutating public func fill() {
        self.isFilled = true
    }
    
    public func filled() -> Triangle {
        var result = self
        result.isFilled = true
        return result
    }

    public func generatePointsForDrawing() -> [(Int, Int)] {
        
        var result = [Point]()
        
        switch isFilled {
        case true:
            
            let boundingBoxHeight = max(abs(p2.y-p1.y), abs(p3.y-p2.y), abs(p1.y-p3.y))
            var buff_x0 = Array<Int>()
            var buff_x1 = Array<Int>()
            
            let linesPoints = [(p1, p2), (p2, p3), (p3, p1)]
            for (start, end) in linesPoints {
                let Δy = end.y - start.y
                if Δy < 0 {
                    (start.x == end.x ? pointsForVerticalLine(from: start, to: end).dropFirst() : pointsForLine(from: start, to: end).dropFirst())
                        .forEach({
                            buff_x0.append($0.x)
                        })
                } else if Δy > 0 {
                    (start.x == end.x ? pointsForVerticalLine(from: start, to: end).dropFirst() : pointsForLine(from: start, to: end).dropFirst())
                        .forEach({
                            buff_x1.append($0.x)
                        })
                } else { // Δy == 0
                    buff_x0.append(start.x)
                    buff_x1.append(end.x)
                }
            }
            
            for y in 0..<boundingBoxHeight {
                result.append(contentsOf: pointsForHorizontalLine(from: Point(x: buff_x0[y], y: y),
                                                                  to: Point(x: buff_x1[y], y: y)))
            }
            
            result.append(p1)
            result.append(p2)
            result.append(p3)
        case false:
            if (p1.x == p2.x) {
                result.append(contentsOf: pointsForVerticalLine(from: p1, to: p2))
            } else if (p1.y == p2.y) {
                result.append(contentsOf: pointsForHorizontalLine(from: p1, to: p2))
            } else {
                result.append(contentsOf: pointsForLine(from: p1, to: p2))
            }
            
            if (p2.x == p3.x) {
                result.append(contentsOf: pointsForVerticalLine(from: p2, to: p3))
            } else if (p2.y == p3.y) {
                result.append(contentsOf: pointsForHorizontalLine(from: p2, to: p3))
            } else {
                result.append(contentsOf: pointsForLine(from: p2, to: p3))
            }
            
            if (p1.x == p3.x) {
                result.append(contentsOf: pointsForVerticalLine(from: p1, to: p3))
            } else if (p1.y == p3.y) {
                result.append(contentsOf: pointsForHorizontalLine(from: p1, to: p3))
            } else {
                result.append(contentsOf: pointsForLine(from: p1, to: p3))
            }
        }
        
        return result.movedTo(origin).convertedToCoordinates()
        
    }

}

//Text
fileprivate extension String {
    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}
public struct Text: Drawable {
    public var origin: Point
    public var text: String
    private var library: FT_Library?
    private var face: FT_Face?
    
    private func getDefaultFontPath() -> String {
        
        let defaultPathForRaspbian = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        guard FileManager.default.fileExists(atPath: defaultPathForRaspbian) else {
            let task = Process()
            if #available(OSX 10.13, *) {
                task.executableURL = URL(fileURLWithPath: "/bin/sh")
            } else {
                task.launchPath = "/bin/sh"
            }
            task.arguments = ["-c", "fc-list"]
            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            
            if #available(OSX 10.13, *) {
                try? task.run()
            } else {
                task.launch()
            }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            
            guard let pathToFirstFoundFont = output.components(separatedBy: "\n").first?.matchingStrings(regex: "^(\\/[^\\/ ]*)+\\/([^:]*)?").first?.first else {
                fatalError("Can not determin default font, please specify one!")
            }
            return pathToFirstFoundFont
        }
        return defaultPathForRaspbian
    }
    
    public init(_ text: String, font pathToFont: String? = nil, at origin: Point = Point(x: 0, y: 0), pixelHeight: UInt32 = 16, pixelWidth: UInt32 = 16) {
        self.origin = origin
        self.text = text
        
        guard FT_Init_FreeType(&library) == FT_Err_Ok else {
            fatalError("Error during initialization! Error occured during initialization of the freetype library!")
        }
        
        guard FT_New_Face(library, pathToFont == nil ? getDefaultFontPath() : pathToFont, 0, &face) == FT_Err_Ok else {
            fatalError("Error during initialization! Please make sure that given path is valid and used file format of font is supported!")
        }
        
        guard FT_Set_Pixel_Sizes(&face!.pointee, pixelHeight, pixelWidth) == FT_Err_Ok else {
            fatalError("Error during initialization! Can not set char pixel for a choosen face!")
        }
        
    }
    
    public func setChar(height: Int, width: Int, horizontalResolution: UInt32, verticalResolution: UInt32) {
        guard FT_Set_Char_Size(&face!.pointee, height, width, horizontalResolution, verticalResolution) == FT_Err_Ok else {
            fatalError("Can not set char size!")
        }
    }
    
    public func setPixel(height: UInt32, width: UInt32) {
        guard FT_Set_Pixel_Sizes(&face!.pointee, height, width) == FT_Err_Ok else {
            fatalError("Can not set pixel size!")
        }
    }
    
    public func generatePointsForDrawing() -> [(Int, Int)] {
        
        var result = [Point]()
        
        
        var previousGlyphIndex: UInt32 = 0
        var summaryLeftOffset: UInt32 = 0
        for character in text {
            for scalar in character.unicodeScalars {
                
                let glyphIndex = FT_Get_Char_Index(face, FT_ULong(scalar.value))
                
                guard FT_Load_Glyph(face, glyphIndex, FT_Int32(FT_LOAD_MONOCHROME)) == FT_Err_Ok else {
                    fatalError()
                }
                
                guard FT_Render_Glyph(face?.pointee.glyph, FT_RENDER_MODE_MONO) == FT_Err_Ok else {
                    fatalError()
                }
                
                let bitmap = face!.pointee.glyph.pointee.bitmap
                
                //determin kerning offset
                var kerningDistanceVector = FT_Vector(x: 0, y: 0)
                FT_Get_Kerning(face, previousGlyphIndex, glyphIndex, FT_KERNING_DEFAULT.rawValue, &kerningDistanceVector)
                //print("Kerning: \(kerningDistanceVector.x)")
                
                //adjust summary offset
                let adjustedOffset = Int(summaryLeftOffset) + kerningDistanceVector.x
                
                //adjust down offset, which aligns glyphs along their baseline
                let downOffset = -(face!.pointee.glyph.pointee.metrics.horiBearingY >> 6) + (face!.pointee.size.pointee.metrics.ascender>>6)
                
                for y in 0..<bitmap.rows {
                    for x in 0..<bitmap.pitch {
                        let byte = bitmap.buffer![Int(y*UInt32(bitmap.pitch)+UInt32(x))]
                        var power: UInt8 = 0
                        while power < 8 {
                            let mask: UInt8 = UInt8(pow(2.0,Double(power)))
                            if byte & mask > 0 {
                                //print("Adding point for:\nbyte:\t\(String(byte, radix: 2))\nmask:\t\(String(mask, radix: 2))")
                                result.append(Point(x: Int(x)*8+Int(7-power) +  adjustedOffset,
                                                    y: Int(y)+Int(downOffset)))
                            }
                            power += 1
                        }
                    }
                }
                previousGlyphIndex = glyphIndex
                summaryLeftOffset += UInt32(face!.pointee.glyph.pointee.metrics.horiAdvance) >> 6
            }
        }
        return result.movedTo(origin).convertedToCoordinates()
    }
    
    
}
