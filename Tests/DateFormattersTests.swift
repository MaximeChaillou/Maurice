import XCTest
@testable import Maurice

final class DateFormattersTests: XCTestCase {

    // MARK: - dayOnly

    func testDayOnlyFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DateFormatters.dayOnly.timeZone
        let components = DateComponents(year: 2026, month: 3, day: 15)
        let date = calendar.date(from: components)!
        XCTAssertEqual(DateFormatters.dayOnly.string(from: date), "2026-03-15")
    }

    func testDayOnlyParsesBack() {
        let str = "2026-01-01"
        let date = DateFormatters.dayOnly.date(from: str)
        XCTAssertNotNil(date)
        XCTAssertEqual(DateFormatters.dayOnly.string(from: date!), str)
    }

    // MARK: - dayAndTime

    func testDayAndTimeFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DateFormatters.dayAndTime.timeZone
        let components = DateComponents(year: 2026, month: 12, day: 25, hour: 14, minute: 30)
        let date = calendar.date(from: components)!
        XCTAssertEqual(DateFormatters.dayAndTime.string(from: date), "2026-12-25 14:30")
    }

    func testDayAndTimeRoundtrip() {
        let str = "2026-06-15 09:05"
        let date = DateFormatters.dayAndTime.date(from: str)
        XCTAssertNotNil(date)
        XCTAssertEqual(DateFormatters.dayAndTime.string(from: date!), str)
    }

    // MARK: - timeOnly

    func testTimeOnlyFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DateFormatters.timeOnly.timeZone
        let components = DateComponents(year: 2026, month: 1, day: 1, hour: 8, minute: 5)
        let date = calendar.date(from: components)!
        XCTAssertEqual(DateFormatters.timeOnly.string(from: date), "08:05")
    }

    // MARK: - dayPOSIX

    func testDayPOSIXFormatMatchesDayOnly() {
        let str = "2026-03-27"
        let posixDate = DateFormatters.dayPOSIX.date(from: str)
        XCTAssertNotNil(posixDate)
        XCTAssertEqual(DateFormatters.dayPOSIX.string(from: posixDate!), str)
    }

    func testDayPOSIXLocaleIsFixed() {
        XCTAssertEqual(DateFormatters.dayPOSIX.locale.identifier, "en_US_POSIX")
    }

    // MARK: - fileTimestamp

    func testFileTimestampFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DateFormatters.fileTimestamp.timeZone
        let components = DateComponents(year: 2026, month: 3, day: 27, hour: 14, minute: 30, second: 45)
        let date = calendar.date(from: components)!
        XCTAssertEqual(DateFormatters.fileTimestamp.string(from: date), "2026-03-27_14-30-45")
    }

    func testFileTimestampRoundtrip() {
        let str = "2026-01-01_00-00-00"
        let date = DateFormatters.fileTimestamp.date(from: str)
        XCTAssertNotNil(date)
        XCTAssertEqual(DateFormatters.fileTimestamp.string(from: date!), str)
    }
}
