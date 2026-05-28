import XCTest

final class NetworkRecoveryControllerTests: XCTestCase {
    func testParsesPreferredNetworkNames() {
        let output = """
        Preferred networks on en0:
        \tHome Wi-Fi
        \tMin iPhone
        \tAirportWiFi(Free FAST)
        \tHome Wi-Fi
        """

        XCTAssertEqual(NetworkRecoveryConnector.preferredNetworkNames(from: output), [
            "Home Wi-Fi",
            "Min iPhone",
            "AirportWiFi(Free FAST)",
        ])
    }

    func testParsesCurrentNetworkName() {
        XCTAssertEqual(
            NetworkRecoveryConnector.currentNetworkName(from: "Current Wi-Fi Network: Min iPhone\n"),
            "Min iPhone"
        )
    }

    func testIgnoresMissingCurrentNetwork() {
        XCTAssertNil(
            NetworkRecoveryConnector.currentNetworkName(
                from: "You are not associated with an AirPort network.\n"
            )
        )
    }

    func testUniqueNetworkNamesTrimsAndDeduplicates() {
        XCTAssertEqual(NetworkRecoveryConnector.uniqueNetworkNames([
            " Min iPhone ",
            "",
            "Min iPhone",
            "Home Wi-Fi",
        ]), [
            "Min iPhone",
            "Home Wi-Fi",
        ])
    }
}
