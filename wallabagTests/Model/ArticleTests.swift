//
//  ArticleTests.swift
//  wallabag
//
//  Created by maxime marinel on 10/11/2016.
//  Copyright © 2016 maxime marinel. All rights reserved.
//

import XCTest
@testable import wallabag

class ArticleTests: XCTestCase {

    func testInitFromDictionary() {
        let article = Article(fromDictionary: [
            "title": "my title",
            "content": "<b>awesome content</b>",
            "domain_name": "wallabag.org",
            "id": 42,
            "created_at": "",
            "updated_at": "",
            "is_archived": false,
            "is_starred": false,
            "mimetype": "txt",
            "reading_time": 2,
            "tags": [],
            "user_email": "user@mail.com",
            "user_id": 1,
            "user_name": "wallabag",
        ]
        )

        XCTAssertEqual("my title", article.title)
        XCTAssertEqual("<b>awesome content</b>", article.content)
        XCTAssertEqual("wallabag.org", article.domain_name)
        XCTAssertEqual(42, article.id)
        XCTAssertEqual(false, article.is_archived)
        XCTAssertEqual(false, article.is_starred)
        XCTAssertEqual("", article.language)
        XCTAssertEqual("txt", article.mimetype)
        XCTAssertNil(article.preview_picture)
        XCTAssertEqual(2, article.reading_time)
        XCTAssertEqual(0, article.tags.count)
        XCTAssertEqual("", article.url)
        XCTAssertEqual("user@mail.com", article.user_email)
        XCTAssertEqual(1, article.user_id)
        XCTAssertEqual("wallabag", article.user_name)
    }

}