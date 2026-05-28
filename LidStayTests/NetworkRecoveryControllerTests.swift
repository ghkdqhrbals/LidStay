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

    func testBuildsSetAirportNetworkArgumentsWithoutPassword() {
        XCTAssertEqual(
            NetworkRecoveryConnector.setAirportNetworkArguments(
                device: "en0",
                ssid: "Min iPhone",
                password: ""
            ),
            ["-setairportnetwork", "en0", "Min iPhone"]
        )
    }

    func testBuildsSetAirportNetworkArgumentsWithPassword() {
        XCTAssertEqual(
            NetworkRecoveryConnector.setAirportNetworkArguments(
                device: "en0",
                ssid: "Min iPhone",
                password: " hotspot-password "
            ),
            ["-setairportnetwork", "en0", "Min iPhone", "hotspot-password"]
        )
    }

    func testBuildsSetAirportPowerOnArguments() {
        XCTAssertEqual(
            NetworkRecoveryConnector.setAirportPowerArguments(device: "en0", isOn: true),
            ["-setairportpower", "en0", "on"]
        )
    }

    func testRedactsPasswordFromAirportNetworkCommandLog() {
        XCTAssertEqual(
            NetworkRecoveryConnector.redactedAirportNetworkCommand(
                device: "en0",
                ssid: "Min iPhone",
                password: "secret-password"
            ),
            "/usr/sbin/networksetup -setairportnetwork en0 \"Min iPhone\" <redacted>"
        )
    }

    func testTreatsCouldNotFindNetworkOutputAsJoinFailure() {
        XCTAssertTrue(
            NetworkRecoveryConnector.commandOutputReportsJoinFailure("Could not find network Min iPhone.")
        )
    }

    func testParsesLocalNetworkNamesFromSystemProfiler() {
        let output = """
        Wi-Fi:

              Interfaces:
                en0:
                  Current Network Information:
                    Coffeebean:
                      PHY Mode: 802.11ac
                  Other Local Wi-Fi Networks:
                    Coffeebean:
                      PHY Mode: 802.11b/g/n
                    Min iPhone:
                      PHY Mode: 802.11b/g/n/ax
                    U+Net8AD4:
                      PHY Mode: 802.11b/g/n/ax
                awdl0:
                  Current Network Information:
                      Network Type: Infrastructure
        """

        XCTAssertEqual(
            NetworkRecoveryConnector.localNetworkNames(fromSystemProfiler: output),
            ["Coffeebean", "Min iPhone", "U+Net8AD4"]
        )
    }

    func testConnectionVerificationFailureShowsCurrentNetworkMismatch() {
        XCTAssertEqual(
            NetworkRecoveryConnector.connectionVerificationFailureMessage(
                targetSSID: "Min iPhone",
                currentSSID: "Office Wi-Fi"
            ),
            "networksetup finished, but Wi-Fi is still connected to \"Office Wi-Fi\" instead of \"Min iPhone\""
        )
    }

    func testConnectionVerificationFailureShowsMissingJoin() {
        XCTAssertEqual(
            NetworkRecoveryConnector.connectionVerificationFailureMessage(
                targetSSID: "Min iPhone",
                currentSSID: nil
            ),
            "networksetup finished, but Wi-Fi did not join \"Min iPhone\""
        )
    }

    func testHotspotNotBroadcastingMessageExplainsIPhoneRequirement() {
        XCTAssertEqual(
            NetworkRecoveryConnector.hotspotNotBroadcastingMessage(targetSSID: "Min iPhone"),
            "hotspot \"Min iPhone\" is not broadcasting as a regular Wi-Fi network. Open Personal Hotspot on iPhone and keep Allow Others to Join enabled."
        )
    }
}
