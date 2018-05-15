# encoding: utf-8

# App Store Review Printer.
# Copyright (C) 2018, Aleh Dzenisiuk. All rights reserved.

from flask import Flask
import lorem
import random

random.seed(123)

def json_for_review(review):
    return """{"author":{"uri":{"label":"https://itunes.apple.com/us/reviews/id326193131"},"name":{"label":"%s"},"label":""},"im:version":{"label":"21.0"},"im:rating":{"label":"%d"},"id":{"label":"%d"},"title":{"label":"%s"},"content":{"label":"%s","attributes":{"type":"text"}},"link":{"attributes":{"rel":"related","href":"https://itunes.apple.com/us/review?id=389801252&type=Purple%%20Software"}},"im:voteSum":{"label":"0"},"im:contentType":{"attributes":{"term":"Application","label":"Application"}},"im:voteCount":{"label":"0"}}""" % (review["author"], review["rating"], review["id"], review["title"], review["body"])

review_feed = []
next_review_id = 1

app = Flask(__name__)

@app.route("/")
def feed():
    
    header = """{"feed": {
        "author": {"name":{"label":"iTunes Store"},"uri":{"label":"http://www.apple.com/itunes/"}},
        "entry": [
            {"im:name":{"label":"Instagram"},"rights":{"label":"© 2015 Instagram, LLC."},"im:price":{"label":"Get","attributes":{"amount":"0.00000","currency":"USD"}},"im:image":[{"label":"http://is4.mzstatic.com/image/thumb/Purple128/v4/bb/ab/25/bbab25cd-f94b-3735-9a36-3743db54df87/Prod-1x_U007emarketing-85-220-0-5.png/53x53bb-85.png","attributes":{"height":"53"}},{"label":"http://is1.mzstatic.com/image/thumb/Purple128/v4/bb/ab/25/bbab25cd-f94b-3735-9a36-3743db54df87/Prod-1x_U007emarketing-85-220-0-5.png/75x75bb-85.png","attributes":{"height":"75"}},{"label":"http://is2.mzstatic.com/image/thumb/Purple128/v4/bb/ab/25/bbab25cd-f94b-3735-9a36-3743db54df87/Prod-1x_U007emarketing-85-220-0-5.png/100x100bb-85.png","attributes":{"height":"100"}}],"im:artist":{"label":"Instagram, Inc.","attributes":{"href":"https://itunes.apple.com/us/developer/instagram-inc/id389801255?mt=8&uo=2"}},"title":{"label":"Instagram - Instagram, Inc."},"link":{"attributes":{"rel":"alternate","type":"text/html","href":"https://itunes.apple.com/us/app/instagram/id389801252?mt=8&uo=2"}},"id":{"label":"https://itunes.apple.com/us/app/instagram/id389801252?mt=8&uo=2","attributes":{"im:id":"389801252","im:bundleId":"com.burbn.instagram"}},"im:contentType":{"attributes":{"term":"Application","label":"Application"}},"category":{"attributes":{"im:id":"6008","term":"Photo & Video","scheme":"https://itunes.apple.com/us/genre/ios-photo-video/id6008?mt=8&uo=2","label":"Photo & Video"}},"im:releaseDate":{"label":"2010-10-06T01:12:41-07:00","attributes":{"label":"October 6, 2010"}}},
"""
   
    footer = """
        ],
        "updated": {
            "label": "2017-10-31T11:17:05-07:00"
        },
        "rights": {
            "label": "Copyright 2008 Apple Inc."
        },
        "title": {
            "label": "iTunes Store: Customer Reviews"
        },
        "icon": {
            "label": "http://itunes.apple.com/favicon.ico"
        },
        "link": [{"attributes":{"rel":"alternate","type":"text/html","href":"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?cc=us&id=1"}},{"attributes":{"rel":"self","href":"https://itunes.apple.com/us/rss/customerreviews/id=389801252/sortby=mostrecent/json"}},{"attributes":{"rel":"first","href":"https://itunes.apple.com/us/rss/customerreviews/page=1/id=389801252/sortby=mostrecent/xml?urlDesc=/customerreviews/id=389801252/sortby=mostrecent/json"}},{"attributes":{"rel":"last","href":"https://itunes.apple.com/us/rss/customerreviews/page=10/id=389801252/sortby=mostrecent/xml?urlDesc=/customerreviews/id=389801252/sortby=mostrecent/json"}},{"attributes":{"rel":"previous","href":"https://itunes.apple.com/us/rss/customerreviews/page=1/id=389801252/sortby=mostrecent/xml?urlDesc=/customerreviews/id=389801252/sortby=mostrecent/json"}},{"attributes":{"rel":"next","href":"https://itunes.apple.com/us/rss/customerreviews/page=2/id=389801252/sortby=mostrecent/xml?urlDesc=/customerreviews/id=389801252/sortby=mostrecent/json"}}],
        "id": {
            "label": "https://itunes.apple.com/us/rss/customerreviews/id=389801252/sortby=mostrecent/json"
        }
    }
}
"""

    num_changes = random.randint(1, 3)
    print("Number of changes: %d" % (num_changes,))
    new_reviews = []
    for i in range(num_changes):
        action = random.choice(['insert', 'delete', 'change', 'change'])
        if action == 'insert':
            global next_review_id
            print("Adding #%d" % (next_review_id,))
            new_reviews.append({
                "rating" : random.randint(1, 5),
                "id" : next_review_id,
                "body" : lorem.paragraph(),
                "title" : lorem.sentence(),
                "author" : lorem.sentence()
            })
            next_review_id = next_review_id + 1
        elif action == 'delete':
            if len(new_reviews) > 0:
                index = random.randint(0, len(new_reviews) - 1)
                print("Removing at %d", index)
                new_reviews.pop(index)
        elif action == 'change':
            r = random.choice(review_feed)
            field = random.choice(['body', 'title', 'rating', 'rating'])
            print("Changing %s of #%d" % (field, r["id"]))
            if field == 'body':
                r["body"] = lorem.paragraph()
            elif field == 'title':
                r["title"] = lorem.sentence()
            elif field == 'rating':
                r["rating"] = random.randint(1, 5)
    
    for r in new_reviews:
        review_feed.insert(0, r)
    
    return header + ",".join(map(json_for_review, review_feed)) + footer

if __name__ == '__main__':
    app.run(host = "0.0.0.0")