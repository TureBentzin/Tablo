#include "test_data.h"
#include "test_framework.h"

#include <csv_manager.h>

TABLO_TEST("csv manager exposes transferred file metadata") {
  CsvManager manager;
  manager.setFile(tablo::test::makeFile());

  TABLO_CHECK_EQ(manager.getFilePath(), std::string("transferred.csv"));
  TABLO_CHECK_EQ(manager.getRowCount(), 4);
  TABLO_CHECK_EQ(manager.getColumnCount(), 2);
  TABLO_CHECK_EQ(manager.getColumnByIndex(0)->length(), 4);
}

TABLO_TEST("csv manager returns inclusive row and column viewport bounds") {
  CsvManager manager;
  manager.setFile(tablo::test::makeFile());

  auto viewport = manager.getViewport(11, 12, 0, 0);

  TABLO_CHECK_EQ(viewport->num_rows(), 2);
  TABLO_CHECK_EQ(viewport->num_columns(), 1);
  TABLO_CHECK_EQ(tablo::test::scalarAt(viewport, 0, 0), std::string("Berlin"));
  TABLO_CHECK_EQ(tablo::test::scalarAt(viewport, 0, 1), std::string("Cologne"));
}

TABLO_TEST("csv manager returns a one-cell viewport") {
  CsvManager manager;
  manager.setFile(tablo::test::makeFile());

  auto viewport = manager.getViewport(10, 10, 1, 1);

  TABLO_CHECK_EQ(viewport->num_rows(), 1);
  TABLO_CHECK_EQ(viewport->num_columns(), 1);
  TABLO_CHECK_EQ(tablo::test::scalarAt(viewport, 0, 0), std::string("10"));
}

TABLO_TEST("csv manager clamps a viewport to its local partition") {
  CsvManager manager;
  manager.setFile(tablo::test::makeFile());

  auto viewport = manager.getViewport(0, 99, -4, 99);

  TABLO_CHECK_EQ(viewport->num_rows(), 4);
  TABLO_CHECK_EQ(viewport->num_columns(), 2);
  TABLO_CHECK_EQ(tablo::test::scalarAt(viewport, 0, 0), std::string("Aachen"));
  TABLO_CHECK_EQ(tablo::test::scalarAt(viewport, 1, 3), std::string("40"));
}

TABLO_TEST("csv manager returns an empty table for disjoint bounds") {
  CsvManager manager;
  manager.setFile(tablo::test::makeFile());

  auto rowsBeforePartition = manager.getViewport(0, 9, 0, 1);
  auto columnsAfterSchema = manager.getViewport(10, 13, 2, 4);

  TABLO_CHECK_EQ(rowsBeforePartition->num_rows(), 0);
  TABLO_CHECK_EQ(rowsBeforePartition->num_columns(), 0);
  TABLO_CHECK_EQ(columnsAfterSchema->num_rows(), 0);
  TABLO_CHECK_EQ(columnsAfterSchema->num_columns(), 0);
}

TABLO_TEST("csv manager executes TQL against the transferred table") {
  CsvManager manager;
  manager.setFile(tablo::test::makeFile());

  auto result = manager.executeQuery("SELECT city FROM ignored.csv WHERE score > 20");

  TABLO_CHECK(result != nullptr);
  TABLO_CHECK_EQ(result->num_rows(), 2);
  TABLO_CHECK_EQ(result->num_columns(), 1);
  TABLO_CHECK_EQ(tablo::test::scalarAt(result, 0, 0), std::string("Cologne"));
  TABLO_CHECK_EQ(tablo::test::scalarAt(result, 0, 1), std::string("Dresden"));
}
