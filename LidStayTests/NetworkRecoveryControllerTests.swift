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

    func testHotspotRecoveryImplementationDoesNotChangeWiFiPowerOrNetworkServiceState() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRootURL = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = projectRootURL.appendingPathComponent("LidStay/NetworkRecoveryController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        // Regression guard: automatic hotspot recovery connects to the target SSID only.
        // It must not change global Wi-Fi power or Network Settings service state.
        XCTAssertFalse(source.contains("-setairportpower"))
        XCTAssertFalse(source.contains("-setnetworkserviceenabled"))
        XCTAssertFalse(source.contains("refreshWiFiRadio"))
        XCTAssertFalse(source.contains("Wi-Fi power off exit="))
        XCTAssertFalse(source.contains("Wi-Fi power command exit="))
        XCTAssertFalse(source.contains("network service turn-on"))
    }

    func testHotspotDiagnosticsDoesNotDetachFromCancellation() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRootURL = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = projectRootURL.appendingPathComponent("LidStay/NetworkRecoveryController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "static func connectWithDiagnostics"))
        let end = try XCTUnwrap(source.range(of: "static func setAirportNetworkArguments"))
        let implementation = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertFalse(implementation.contains("Task.detached"))
        XCTAssertTrue(implementation.contains("guard !Task.isCancelled"))
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

    func testSatisfiedPathIsUsableEvenWhenSSIDLookupIsUnavailable() {
        XCTAssertTrue(
            NetworkRecoveryConnector.isUsableNetworkPath(
                statusSatisfied: true,
                requiresWiFiAssociation: true,
                currentWiFiSSID: nil
            )
        )
    }

    func testAttemptsHotspotRecoveryOnlyWhenNetworkIsDownAndTargetIsNotConnected() {
        XCTAssertTrue(
            NetworkRecoveryConnector.shouldAttemptHotspotRecovery(
                isNetworkReachable: false,
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )

        XCTAssertTrue(
            NetworkRecoveryConnector.shouldAttemptHotspotRecovery(
                isNetworkReachable: false,
                currentSSID: "Office Wi-Fi",
                targetSSID: "Min iPhone"
            )
        )
    }

    func testDoesNotAttemptHotspotRecoveryWhenNetworkIsReachable() {
        XCTAssertFalse(
            NetworkRecoveryConnector.shouldAttemptHotspotRecovery(
                isNetworkReachable: true,
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )
    }

    func testDoesNotAttemptHotspotRecoveryWhenTargetIsAlreadyConnected() {
        XCTAssertFalse(
            NetworkRecoveryConnector.shouldAttemptHotspotRecovery(
                isNetworkReachable: false,
                currentSSID: "Min iPhone",
                targetSSID: "Min iPhone"
            )
        )
    }

    func testStartsHotspotConnectionOnlyWhenNetworkPathIsCurrentlyUnavailable() {
        XCTAssertTrue(
            NetworkRecoveryConnector.shouldStartHotspotConnection(
                pathSatisfied: false,
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )

        XCTAssertFalse(
            NetworkRecoveryConnector.shouldStartHotspotConnection(
                pathSatisfied: true,
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )

        XCTAssertFalse(
            NetworkRecoveryConnector.shouldStartHotspotConnection(
                pathSatisfied: false,
                currentSSID: "Min iPhone",
                targetSSID: "Min iPhone"
            )
        )
    }

    func testAttemptsBatteryTransitionHotspotRecoveryWhenNetworkIsDown() {
        XCTAssertTrue(
            NetworkRecoveryConnector.shouldAttemptBatteryTransitionHotspotRecovery(
                pathSatisfied: false,
                pathUsesWiFi: false,
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )
    }

    func testDoesNotAttemptHotspotRecoveryWhenSatisfiedWiFiPathHasNoSSID() {
        XCTAssertFalse(
            NetworkRecoveryConnector.shouldAttemptBatteryTransitionHotspotRecovery(
                pathSatisfied: true,
                pathUsesWiFi: true,
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )
    }

    func testDoesNotAttemptBatteryTransitionHotspotRecoveryWhenNonWiFiPathIsSatisfied() {
        XCTAssertFalse(
            NetworkRecoveryConnector.shouldAttemptBatteryTransitionHotspotRecovery(
                pathSatisfied: true,
                pathUsesWiFi: false,
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )
    }

    func testDoesNotForceHotspotRecoveryWhenAnotherWiFiIsUsable() {
        XCTAssertFalse(
            NetworkRecoveryConnector.shouldAttemptBatteryTransitionHotspotRecovery(
                pathSatisfied: true,
                pathUsesWiFi: true,
                currentSSID: "Office Wi-Fi",
                targetSSID: "Min iPhone"
            )
        )
    }

    func testDoesNotForceHotspotRecoveryWhenTargetIsAlreadyConnectedOnBatteryTransition() {
        XCTAssertFalse(
            NetworkRecoveryConnector.shouldAttemptBatteryTransitionHotspotRecovery(
                pathSatisfied: true,
                pathUsesWiFi: true,
                currentSSID: "Min iPhone",
                targetSSID: "Min iPhone"
            )
        )
    }

    func testRecoveryWatchdogIntervalIsBounded() {
        XCTAssertEqual(NetworkRecoveryConnector.recoveryWatchdogIntervalSeconds(retryDelay: 1), 3)
        XCTAssertEqual(NetworkRecoveryConnector.recoveryWatchdogIntervalSeconds(retryDelay: 12), 12)
        XCTAssertEqual(NetworkRecoveryConnector.recoveryWatchdogIntervalSeconds(retryDelay: 120), 30)
    }

    func testSatisfiedWiFiPathWithoutSSIDIsAvailableForHotspotStandby() {
        XCTAssertTrue(
            NetworkRecoveryConnector.isNetworkPathAvailableForHotspotStandby(
                pathSatisfied: true,
                pathUsesWiFi: true,
                currentSSID: nil
            )
        )
    }

    func testSatisfiedWiFiPathWithSSIDIsAvailableForHotspotStandby() {
        XCTAssertTrue(
            NetworkRecoveryConnector.isNetworkPathAvailableForHotspotStandby(
                pathSatisfied: true,
                pathUsesWiFi: true,
                currentSSID: "Office Wi-Fi"
            )
        )
    }

    func testSatisfiedNonWiFiPathIsAvailableForHotspotStandbyWithoutSSID() {
        XCTAssertTrue(
            NetworkRecoveryConnector.isNetworkPathAvailableForHotspotStandby(
                pathSatisfied: true,
                pathUsesWiFi: false,
                currentSSID: nil
            )
        )
    }

    func testStartsSwitchGraceWhenLeavingTargetHotspot() {
        XCTAssertTrue(
            NetworkRecoveryConnector.shouldStartHotspotSwitchGrace(
                previousSSID: "Min iPhone",
                currentSSID: "Office Wi-Fi",
                targetSSID: "Min iPhone"
            )
        )

        XCTAssertTrue(
            NetworkRecoveryConnector.shouldStartHotspotSwitchGrace(
                previousSSID: "Min iPhone",
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )
    }

    func testDoesNotStartSwitchGraceForNonTargetNetworkDrop() {
        XCTAssertFalse(
            NetworkRecoveryConnector.shouldStartHotspotSwitchGrace(
                previousSSID: "Office Wi-Fi",
                currentSSID: nil,
                targetSSID: "Min iPhone"
            )
        )
    }

    func testHotspotRecoveryDelayRespectsSwitchGrace() {
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            NetworkRecoveryConnector.hotspotRecoveryDelaySeconds(
                configuredDelay: 1,
                switchGraceUntil: now.addingTimeInterval(11.2),
                now: now
            ),
            12
        )

        XCTAssertEqual(
            NetworkRecoveryConnector.hotspotRecoveryDelaySeconds(
                configuredDelay: 30,
                switchGraceUntil: now.addingTimeInterval(5),
                now: now
            ),
            30
        )
    }

    func testSatisfiedWiFiPathWithAssociationIsUsable() {
        XCTAssertTrue(
            NetworkRecoveryConnector.isUsableNetworkPath(
                statusSatisfied: true,
                requiresWiFiAssociation: true,
                currentWiFiSSID: "Min iPhone"
            )
        )
    }

    func testSkipsHotspotJoinWhenAlreadyConnectedToTargetSSID() {
        XCTAssertTrue(
            NetworkRecoveryConnector.shouldSkipHotspotJoin(
                currentSSID: " Min iPhone ",
                targetSSID: "Min iPhone"
            )
        )
    }

    func testDoesNotSkipHotspotJoinForDifferentSSID() {
        XCTAssertFalse(
            NetworkRecoveryConnector.shouldSkipHotspotJoin(
                currentSSID: "Office Wi-Fi",
                targetSSID: "Min iPhone"
            )
        )
    }

    func testSatisfiedNonWiFiPathIsUsableWithoutWiFiAssociation() {
        XCTAssertTrue(
            NetworkRecoveryConnector.isUsableNetworkPath(
                statusSatisfied: true,
                requiresWiFiAssociation: false,
                currentWiFiSSID: nil
            )
        )
    }

    func testUnsatisfiedPathIsNotUsable() {
        XCTAssertFalse(
            NetworkRecoveryConnector.isUsableNetworkPath(
                statusSatisfied: false,
                requiresWiFiAssociation: false,
                currentWiFiSSID: "Min iPhone"
            )
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

    func testWiFiPoweredOffMessageUsesExplicitOffTerm() {
        XCTAssertEqual(
            NetworkRecoveryConnector.wifiPoweredOffMessage(),
            "Wi-Fi is off. Turn on Wi-Fi to use hotspot auto-connect."
        )
    }
}
