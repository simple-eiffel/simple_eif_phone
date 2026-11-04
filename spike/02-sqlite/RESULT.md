# Spike 02: does simple_sql run on the phone?

**Answer:** Yes, with no change to simple_sql, its libraries, or gec.

gec accepted simple_sql and everything it depends on. The only gap was in `eifphone`, which could not compile C that a library brings with it. The `[native]` table fills that gap. SQLite's C also needs gec's own runtime headers on the include path.

On the emulator, with every contract on, the spike wrote 1,000 rows in a transaction to a file in the app's folder, ran an FTS5 search, closed, and read the file back through a read-only connection.
