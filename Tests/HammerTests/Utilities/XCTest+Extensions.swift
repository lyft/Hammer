import CoreLocation
import CoreGraphics
import XCTest

func XCTAssertEqual(_ expression1: @autoclosure () -> CLLocationCoordinate2D,
                    _ expression2: @autoclosure () -> CLLocationCoordinate2D,
                    accuracy: Double, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line)
{
    let coordinate1 = expression1()
    let coordinate2 = expression2()
    XCTAssertEqual(coordinate1.latitude, coordinate2.latitude, accuracy: accuracy,
                   message(), file: file, line: line)
    XCTAssertEqual(coordinate1.longitude, coordinate2.longitude, accuracy: accuracy,
                   message(), file: file, line: line)
}

func XCTAssertEqual(_ expression1: @autoclosure () -> CGPoint,
                    _ expression2: @autoclosure () -> CGPoint,
                    accuracy: CGFloat, _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line)
{
    let point1 = expression1()
    let point2 = expression2()
    XCTAssertEqual(point1.x, point2.x, accuracy: accuracy, message(), file: file, line: line)
    XCTAssertEqual(point1.y, point2.y, accuracy: accuracy, message(), file: file, line: line)
}
