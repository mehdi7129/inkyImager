import XCTest
@testable import ImagerCore

final class FlashTargetSelectionTests: XCTestCase {
    private let usb = SDCard(id: "disk900", name: "Fixture USB", capacity: 16_000_000_000, registryID: 100)

    func testSingleDeviceRequiresExplicitSelectionAndApproval() {
        var selection = FlashTargetSelection()
        selection.replaceDevices([usb])
        XCTAssertNil(selection.selectedID)
        XCTAssertNil(selection.confirmed { _ in XCTFail("Confirmation without selection"); return true })

        selection.selectedID = usb.id
        XCTAssertNil(selection.confirmed { _ in false })
        XCTAssertEqual(selection.confirmed { $0 == self.usb }, usb)
    }

    func testMediaReplacementAndCollectionChangesInvalidateSelection() {
        var selection = FlashTargetSelection()
        selection.replaceDevices([usb])
        selection.selectedID = usb.id
        let snapshot = selection

        let replacement = SDCard(id: usb.id, name: usb.name, capacity: usb.capacity, registryID: 101)
        selection.replaceDevices([replacement])
        XCTAssertNil(selection.selectedID)
        XCTAssertNotEqual(selection, snapshot)
        selection.replaceDevices([usb])
        selection.selectedID = usb.id
        XCTAssertNotEqual(selection, snapshot)
        selection.replaceDevices([usb])
        XCTAssertEqual(selection.selectedID, usb.id)
        selection.replaceDevices([])
        XCTAssertNil(selection.selectedID)
    }

    func testConfirmationStringsArePresentInEveryCatalog() {
        let keys = ["Effacer et flasher ce support ?", "%@ octets",
                    "Toutes les données du support sélectionné seront effacées.", "Annuler l’effacement"]
        for language in ImagerLanguage.allCases where language != .fr {
            for key in keys {
                let value = ImagerLocalization.text(key, language: language)
                XCTAssertFalse(value.isEmpty)
                XCTAssertNotEqual(value, key, "\(language)")
            }
        }
    }
}
