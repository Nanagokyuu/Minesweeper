//
//  InputBindingsTests.swift
//  MinesweeperTests
//

import XCTest
@testable import Minesweeper

final class InputBindingsTests: XCTestCase {
    func testDefaultsMatchMouseAndLetterKeys() {
        let bindings = InputBindings.default

        XCTAssertTrue(bindings[.dig].contains(.mouse(button: 0)))
        XCTAssertTrue(bindings[.dig].contains(.key(keyCode: 6, modifiers: 0))) // Z
        XCTAssertTrue(bindings[.flag].contains(.mouse(button: 1)))
        XCTAssertTrue(bindings[.flag].contains(.key(keyCode: 7, modifiers: 0))) // X
        XCTAssertTrue(bindings[.chord].contains(.mouse(button: 2)))
        XCTAssertTrue(bindings[.newGame].contains(.key(keyCode: 15, modifiers: 0))) // R
    }

    func testOneActionSupportsMultipleBindings() {
        var bindings = InputBindings.default
        bindings.bind(.key(keyCode: 49, modifiers: 0), to: .dig) // Space
        bindings.bind(.mouse(button: 3), to: .dig)              // Side button 1

        XCTAssertTrue(bindings[.dig].contains(.mouse(button: 0)))
        XCTAssertTrue(bindings[.dig].contains(.key(keyCode: 6, modifiers: 0)))
        XCTAssertTrue(bindings[.dig].contains(.key(keyCode: 49, modifiers: 0)))
        XCTAssertTrue(bindings[.dig].contains(.mouse(button: 3)))
        XCTAssertEqual(bindings[.dig].count, 4)
    }

    func testBindingMovesInsteadOfDuplicating() {
        var bindings = InputBindings.default
        // Left click was dig; move it to flag.
        bindings.bind(.mouse(button: 0), to: .flag)

        XCTAssertNil(bindings.conflictingAction(for: .mouse(button: 0), assignedTo: .flag))
        XCTAssertEqual(bindings.action(for: .mouse(button: 0)), .flag)
        XCTAssertFalse(bindings[.dig].contains(.mouse(button: 0)))
        XCTAssertTrue(bindings[.dig].contains(.key(keyCode: 6, modifiers: 0)))
    }

    func testConflictDetectionBeforeMutation() {
        let bindings = InputBindings.default
        XCTAssertEqual(
            bindings.conflictingAction(for: .key(keyCode: 7, modifiers: 0), assignedTo: .dig),
            .flag
        )
        XCTAssertNil(
            bindings.conflictingAction(for: .key(keyCode: 7, modifiers: 0), assignedTo: .flag)
        )
    }

    func testModifiersArePartOfTheIdentity() {
        var bindings = InputBindings.default
        bindings.bind(.key(keyCode: 6, modifiers: InputModifiers.shift), to: .flag)

        XCTAssertEqual(bindings.actionForKey(keyCode: 6, modifiers: 0), .dig)
        XCTAssertEqual(bindings.actionForKey(keyCode: 6, modifiers: InputModifiers.shift), .flag)
    }

    func testResetRestoresDefaults() {
        var bindings = InputBindings.default
        bindings.unbind(.mouse(button: 0), from: .dig)
        bindings.bind(.mouse(button: 0), to: .chord)
        bindings.reset()

        XCTAssertEqual(bindings, .default)
    }

    func testCodableRoundTripPreservesEveryAction() throws {
        var bindings = InputBindings.default
        bindings.bind(.mouse(button: 4), to: .flag)             // Side button 2
        bindings.bind(.key(keyCode: 49, modifiers: InputModifiers.command), to: .chord)

        let data = try JSONEncoder().encode(bindings)
        let decoded = try JSONDecoder().decode(InputBindings.self, from: data)

        XCTAssertEqual(decoded, bindings)
        XCTAssertTrue(decoded[.flag].contains(.mouse(button: 4)))
        XCTAssertTrue(decoded[.chord].contains(.key(keyCode: 49, modifiers: InputModifiers.command)))
    }
}
