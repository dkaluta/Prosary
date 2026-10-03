#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lxml>=5,<7", "protego>=0.3,<0.7", "lingua-language-detector>=2,<3"]
# ///
"""Offline regressions for TV Maria archive discovery and literal source separation."""
import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("tvmaria", Path(__file__).with_name("scrape-tvmaria-saints.py"))
source = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(source)
URL = source.BASE + "2011/10/01/santa-teresita-ng-nino-jesus/"
# A short literal sample from the public Thérèse entry, preserving its punctuation.
BIO = "Maagang nabalo si Luis Martin. Hinubog niya ang kanyang mga anak sa pamumuhay na angkop sa aral ng Panginoong Diyos, bagay na makikita sa pagiging madre ng apat niyang anak. Hindi nagtagal, pumasok din si Teresita sa monasteryo ng mga Carmelita sa Lisieux noong Abril 9, 1888, sa kabila ng maraming bagay na humadlang sa kanyang pagiging madre."
CREDIT = "Abriol, J. C. (2010). Talambuhay ng mga Santo, volume 2 (3rd ed.). Pasay: Paulines Publishing House"


def fixture(body, title="Santa Teresita ng Niño Jesus", extra=""):
    return '<html lang="en"><div id="content"><div class="post post-1652 type-post"><h2>' + title + '</h2><div class="entrytext">' + body + '<div id="jp-post-flair">Share this: Like Loading...</div><p class="postmetadata">Posted October 1, 2011. Commentary</p></div></div></div><aside>Sidebar saint text</aside>' + extra + '</html>'


class TVMariaTests(unittest.TestCase):
    def record(self, body, **kwargs):
        return source.extract_article(fixture(body, **kwargs), URL)

    def test_published_home_archive_options_only(self):
        page = '<div id="sidebar"><div class="widget widget_archive"><select><option value="">Month</option><option value="https://tvmaria.wordpress.com/2011/10/">October 2011</option><option value="https://external.example/2011/10/">Other</option></select></div></div>'
        self.assertEqual(source.extract_home(page)["archives"], [{"url": source.BASE + "2011/10/", "literalLabel": "October 2011"}])

    def test_actual_older_entries_link(self):
        page = '<div id="content"><h2 class="pagetitle">Archive for June 2011</h2><div class="post post-1 type-post"><h3><a href="/2011/06/30/san-pablo/">San Pablo</a></h3></div><div class="navigation"><a href="/2011/06/page/2/">Older Entries</a></div></div>'
        result = source.extract_archive(page, source.BASE + "2011/06/")
        self.assertEqual(result["posts"][0]["wordPressPostID"], 1)
        self.assertEqual(result["pagination"], [source.BASE + "2011/06/page/2/"])

    def test_cross_month_navigation_is_unrecognized(self):
        page = '<div id="content"><div class="navigation"><a href="/2011/05/page/2/">Older</a></div></div>'
        self.assertTrue(source.extract_archive(page, source.BASE + "2011/06/")["unrecognizedPaginationLinks"])

    def test_actual_month_archive_home_navigation_is_not_pagination(self):
        page = '<div id="content"><div class="navigation"><a href="https://tvmaria.wordpress.com/">Home</a></div></div>'
        result = source.extract_archive(page, source.BASE + "2011/12/")
        self.assertFalse(result["unrecognizedPaginationLinks"])
        self.assertEqual(result["publishedHomeNavigation"], [{"url": source.BASE, "literalLabel": "Home"}])

    def test_url_scope_excludes_login_media_queries_credentials(self):
        for url in ['/wp-admin/', '/wp-login.php', '/2011/10/01/name/feed/', '/wp-content/uploads/photo.jpg', URL + '?share=email', 'https://evil.example/2011/10/01/name/', 'https://name:password@tvmaria.wordpress.com/2011/10/01/name/']:
            with self.subTest(url=url):
                self.assertIsNone(source.canonical_url(url))

    def test_original_paragraphs_and_book_credits_preserved(self):
        record = self.record('<p>' + BIO + '</p><p><strong>ARAL:</strong></p><p>Magtiwala sa Panginoon.</p><p>Source:</p><p>' + CREDIT + '</p>')
        self.assertEqual(record["sourceParagraphs"], [BIO, 'ARAL:', 'Magtiwala sa Panginoon.', 'Source:', CREDIT])
        self.assertEqual(record["sections"]["biography"], [BIO])
        self.assertEqual(record["sections"]["reflection"], ['Magtiwala sa Panginoon.'])
        self.assertEqual(record["literalCredits"][0]["literal"], CREDIT)
        self.assertEqual(record["sourceTextSHA256"], source.digest('\n'.join(record["sourceParagraphs"])))

    def test_inline_reflection_and_credit_markers(self):
        record = self.record('<p>' + BIO + '</p><p><strong>ARAL:</strong> Magtiwala sa Panginoon.</p><p>Source: ' + CREDIT + '</p>')
        self.assertEqual(record["sections"]["reflection"], ['Magtiwala sa Panginoon.'])
        self.assertEqual(record["sections"]["credits"], [CREDIT])

    def test_actual_unheaded_book_and_web_references_are_not_biography(self):
        web = 'n.a. (n.d.). St. Joseph. In Catholic Online. Retrieved March 9, 2011, from http://www.catholic.org/saints/saint.php?saint_id=4'
        record = self.record('<p>' + BIO + '</p><p>' + CREDIT + '.</p><p>' + web + '</p>')
        self.assertEqual(record['sections']['biography'], [BIO])
        self.assertEqual(record['sections']['credits'], [CREDIT + '.', web])
        self.assertEqual([credit['literal'] for credit in record['literalCredits']], [CREDIT + '.', web])
        self.assertEqual(record['sourceParagraphs'], [BIO, CREDIT + '.', web])
        self.assertEqual(record['language'], 'tl')

    def test_narrative_mention_of_a_book_does_not_become_a_contributor(self):
        narrative = 'Binasa niya ang Talambuhay ng mga Santo at sumulat sa kanyang mga kaibigan.'
        record = self.record('<p>' + BIO + '</p><p>' + narrative + '</p>')
        self.assertIn(narrative, record['sections']['biography'])
        self.assertEqual(record['literalCredits'], [])

    def test_book_reference_does_not_make_tagalog_biography_english(self):
        record = self.record('<p>' + BIO + '</p><p>Source:</p><p>' + CREDIT + '</p>')
        self.assertEqual(record["disposition"], "articles")
        self.assertTrue(record["languageEvidence"]["tagalogCandidate"])

    def test_actual_prose_language_ignores_english_html_attribute(self):
        self.assertEqual(self.record('<p>' + BIO + '</p>')["language"], "tl")

    def test_english_saint_post_is_excluded(self):
        record = self.record('<p>She was born in a small town and later became a nun. Her family taught her to trust in God. She lived a life of prayer and helped the people who were sick. The saint wrote many letters to her friends and encouraged them to be kind to others.</p>', title='Saint Therese')
        self.assertEqual(record["classification"], 'English-source-post')
        self.assertIsNone(record["language"])

    def test_non_biographical_tagalog_post_is_excluded(self):
        self.assertEqual(self.record('<p>' + BIO + '</p>', title='Mga Pagbasa sa Araw-Araw')["disposition"], 'excluded')

    def test_sidebar_posting_ui_and_scripts_are_excluded(self):
        record = self.record('<p>' + BIO + '</p><script>Hidden words</script>')
        self.assertEqual(record["sourceParagraphs"], [BIO])
        self.assertNotIn('Commentary', record["sourceHTML"])
        self.assertIn('Hidden words', record["originalEntryHTML"])

    def test_bare_text_image_tails_and_inline_punctuation(self):
        record = self.record('Bare introduction.<p>Text <em>word</em>, more<img alt="Not prose" src="/photo.jpg"> tail.</p>After paragraph.')
        self.assertEqual(record["sourceParagraphs"], ['Bare introduction.', 'Text word, more tail.', 'After paragraph.'])

    def test_posting_date_never_becomes_feast_label(self):
        record = self.record('<p>' + BIO + '</p>')
        self.assertEqual(record["sourceFeastLabels"], [])
        self.assertFalse(record["sourcePostingDateIsFeastDate"])
        record = self.record('<p>Araw ng Kapistahan: Oktubre 1</p><p>' + BIO + '</p>')
        self.assertEqual(record["sourceFeastLabels"], ['Araw ng Kapistahan: Oktubre 1'])

    def test_primary_page_hash_and_title_checks(self):
        page = fixture('<p>' + BIO + '</p>')
        record = source.extract_article(page, URL, index_entries=[{"title": "Wrong title"}])
        self.assertEqual(record["sourcePageHTMLSHA256"], source.digest(page))
        self.assertIn('index-article-title-mismatch', record["review"]["reasons"])

    def test_missing_primary_body_is_quarantined(self):
        self.assertEqual(source.extract_article('<div id="content">No post</div>', URL)["disposition"], 'quarantine')

    def test_actual_untitled_post_keeps_every_source_paragraph(self):
        record = self.record('<p>Alleluia, nabuhay ang Panginoon!</p>', title='')
        self.assertEqual(record['classification'], 'untitled-source-post')
        self.assertEqual(record['sourceParagraphs'], ['Alleluia, nabuhay ang Panginoon!'])
        self.assertEqual(record['review']['reasons'], ['source-title-empty'])

    def test_malformed_utf8_fails_without_replacement(self):
        with self.assertRaises(UnicodeDecodeError):
            source.parse_html(b'<div>Ni\xffo</div>')
        page = fixture('<p>Niño — “Teresita”</p>').encode('utf-8')
        self.assertEqual(source.extract_article(page, URL)["sourceParagraphs"], ['Niño — “Teresita”'])


if __name__ == '__main__':
    unittest.main()
