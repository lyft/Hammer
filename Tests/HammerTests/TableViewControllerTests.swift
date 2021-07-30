//
//  ScrollableViewControllerTests.swift
//  HammerTests
//
//  Created by Łukasz Rutkowski on 28/07/2021.
//

import Foundation
import Hammer
import XCTest

final class TableViewControllerTests: XCTestCase {

    func testFindViewAfterScrolling() throws{
        let viewController = TableViewController()
        let eventGenerator = try EventGenerator(viewController: viewController)
        try eventGenerator.waitUntilVisible("accessibilityId_0-1", timeout: 1)

        viewController.tableView.scrollToRow(at: IndexPath(row: 40, section: 0), at: .bottom, animated: false)
        XCTAssertTrue(eventGenerator.viewIsVisible("accessibilityId_0-35"))
    }
}

final class TableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TableViewCell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 50
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TableViewCell", for: indexPath)
        let id = "\(indexPath.section)-\(indexPath.row)"
        cell.textLabel?.text = "title_\(id)"
        cell.accessibilityIdentifier = "accessibilityId_\(id)"
        return cell
    }
}
