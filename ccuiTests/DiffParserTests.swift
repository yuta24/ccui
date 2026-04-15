import Testing
@testable import ccui

struct DiffParserTests {

    // MARK: - Empty Input

    @Test func parseEmptyString() {
        let result = DiffParser.parse("")
        #expect(result.isEmpty)
    }

    @Test func parseNoGitDiffHeaders() {
        let result = DiffParser.parse("some random text\nwithout diff headers")
        #expect(result.isEmpty)
    }

    // MARK: - Modified File

    @Test func parseModifiedFile() {
        let diff = """
        diff --git a/file.swift b/file.swift
        index abc1234..def5678 100644
        --- a/file.swift
        +++ b/file.swift
        @@ -1,3 +1,4 @@
         line1
        -old line
        +new line
        +added line
         line3
        """
        let entries = DiffParser.parse(diff)
        #expect(entries.count == 1)

        let entry = entries[0]
        #expect(entry.status == .modified)
        #expect(entry.oldPath == "file.swift")
        #expect(entry.newPath == "file.swift")
        #expect(entry.isBinary == false)
        #expect(entry.additions == 2)
        #expect(entry.deletions == 1)
        #expect(entry.hunks.count == 1)

        let hunk = entry.hunks[0]
        #expect(hunk.lines.count == 5)
        #expect(hunk.lines[0].kind == .context)
        #expect(hunk.lines[1].kind == .deletion)
        #expect(hunk.lines[2].kind == .addition)
        #expect(hunk.lines[3].kind == .addition)
        #expect(hunk.lines[4].kind == .context)
    }

    // MARK: - Added File

    @Test func parseAddedFile() {
        let diff = """
        diff --git a/new.swift b/new.swift
        new file mode 100644
        index 0000000..abc1234
        --- /dev/null
        +++ b/new.swift
        @@ -0,0 +1,2 @@
        +first line
        +second line
        """
        let entries = DiffParser.parse(diff)
        #expect(entries.count == 1)

        let entry = entries[0]
        #expect(entry.status == .added)
        #expect(entry.oldPath == "")
        #expect(entry.newPath == "new.swift")
        #expect(entry.additions == 2)
        #expect(entry.deletions == 0)
    }

    // MARK: - Deleted File

    @Test func parseDeletedFile() {
        let diff = """
        diff --git a/old.swift b/old.swift
        deleted file mode 100644
        index abc1234..0000000
        --- a/old.swift
        +++ /dev/null
        @@ -1,2 +0,0 @@
        -removed line 1
        -removed line 2
        """
        let entries = DiffParser.parse(diff)
        #expect(entries.count == 1)

        let entry = entries[0]
        #expect(entry.status == .deleted)
        #expect(entry.oldPath == "old.swift")
        #expect(entry.newPath == "")
        #expect(entry.additions == 0)
        #expect(entry.deletions == 2)
    }

    // MARK: - Renamed File

    @Test func parseRenamedFile() {
        let diff = """
        diff --git a/old_name.swift b/new_name.swift
        similarity index 100%
        rename from old_name.swift
        rename to new_name.swift
        """
        let entries = DiffParser.parse(diff)
        #expect(entries.count == 1)

        let entry = entries[0]
        #expect(entry.status == .renamed)
        #expect(entry.oldPath == "old_name.swift")
        #expect(entry.newPath == "new_name.swift")
    }

    // MARK: - Binary File

    @Test func parseBinaryFile() {
        let diff = """
        diff --git a/image.png b/image.png
        index abc1234..def5678 100644
        Binary files a/image.png and b/image.png differ
        """
        let entries = DiffParser.parse(diff)
        #expect(entries.count == 1)
        #expect(entries[0].isBinary == true)
    }

    // MARK: - Multiple Files

    @Test func parseMultipleFiles() {
        let diff = """
        diff --git a/a.swift b/a.swift
        index abc..def 100644
        --- a/a.swift
        +++ b/a.swift
        @@ -1,1 +1,1 @@
        -old
        +new
        diff --git a/b.swift b/b.swift
        new file mode 100644
        index 0000000..abc1234
        --- /dev/null
        +++ b/b.swift
        @@ -0,0 +1,1 @@
        +content
        """
        let entries = DiffParser.parse(diff)
        #expect(entries.count == 2)
        #expect(entries[0].status == .modified)
        #expect(entries[1].status == .added)
    }

    // MARK: - Hunk Line Numbers

    @Test func parseHunkLineNumbers() {
        let diff = """
        diff --git a/file.swift b/file.swift
        index abc..def 100644
        --- a/file.swift
        +++ b/file.swift
        @@ -10,3 +10,4 @@
         context
        -deleted
        +added1
        +added2
         context2
        """
        let entries = DiffParser.parse(diff)
        let lines = entries[0].hunks[0].lines

        // Context line: old=10, new=10
        #expect(lines[0].oldLineNumber == 10)
        #expect(lines[0].newLineNumber == 10)

        // Deletion: old=11, new=nil
        #expect(lines[1].oldLineNumber == 11)
        #expect(lines[1].newLineNumber == nil)

        // Addition: old=nil, new=11
        #expect(lines[2].oldLineNumber == nil)
        #expect(lines[2].newLineNumber == 11)

        // Second addition: old=nil, new=12
        #expect(lines[3].oldLineNumber == nil)
        #expect(lines[3].newLineNumber == 12)

        // Context: old=12, new=13
        #expect(lines[4].oldLineNumber == 12)
        #expect(lines[4].newLineNumber == 13)
    }

    // MARK: - Multiple Hunks

    @Test func parseMultipleHunks() {
        let diff = """
        diff --git a/file.swift b/file.swift
        index abc..def 100644
        --- a/file.swift
        +++ b/file.swift
        @@ -1,2 +1,2 @@
        -old1
        +new1
         ctx
        @@ -20,2 +20,2 @@
        -old2
        +new2
         ctx2
        """
        let entries = DiffParser.parse(diff)
        #expect(entries[0].hunks.count == 2)
        #expect(entries[0].hunks[0].lines[0].oldLineNumber == 1)
        #expect(entries[0].hunks[1].lines[0].oldLineNumber == 20)
    }

    // MARK: - Line Content

    @Test func parsedLineContentStripsPrefix() {
        let diff = """
        diff --git a/file.swift b/file.swift
        index abc..def 100644
        --- a/file.swift
        +++ b/file.swift
        @@ -1,3 +1,3 @@
         context line
        -deleted line
        +added line
        """
        let lines = DiffParser.parse(diff)[0].hunks[0].lines
        #expect(lines[0].content == "context line")
        #expect(lines[1].content == "deleted line")
        #expect(lines[2].content == "added line")
    }

    // MARK: - No Newline at End

    @Test func parseNoNewlineMarker() {
        let diff = """
        diff --git a/file.swift b/file.swift
        index abc..def 100644
        --- a/file.swift
        +++ b/file.swift
        @@ -1,1 +1,1 @@
        -old
        \\ No newline at end of file
        +new
        \\ No newline at end of file
        """
        let entries = DiffParser.parse(diff)
        #expect(entries[0].hunks[0].lines.count == 2)
        #expect(entries[0].deletions == 1)
        #expect(entries[0].additions == 1)
    }
}
