#ifndef TABLO_TEST_DATA_H
#define TABLO_TEST_DATA_H

#include <arrow/api.h>
#include <server_session_controller.h>

#include <memory>
#include <stdexcept>
#include <string>

namespace tablo::test {

inline void requireArrow(const arrow::Status& status) {
  if (!status.ok()) {
    throw std::runtime_error(status.ToString());
  }
}

template <typename Builder>
std::shared_ptr<arrow::Array> finishArray(Builder& builder) {
  auto result = builder.Finish();
  if (!result.ok()) {
    throw std::runtime_error(result.status().ToString());
  }
  return result.ValueOrDie();
}

inline ttp2::ServerSessionController::File makeFile(int start = 10) {
  arrow::StringBuilder cityBuilder;
  requireArrow(cityBuilder.AppendValues({"Aachen", "Berlin", "Cologne", "Dresden"}));

  arrow::Int64Builder scoreBuilder;
  requireArrow(scoreBuilder.AppendValues({10, 20, 30, 40}));

  auto table = arrow::Table::Make(
      arrow::schema({arrow::field("city", arrow::utf8()), arrow::field("score", arrow::int64())}),
      {finishArray(cityBuilder), finishArray(scoreBuilder)});

  ttp2::ServerSessionController::File file;
  file.filePath = "transferred.csv";
  file.start = start;
  file.end = start + static_cast<int>(table->num_rows()) - 1;
  file.payload = std::move(table);
  return file;
}

inline std::string scalarAt(const std::shared_ptr<arrow::Table>& table, int column, int row) {
  auto scalar = table->column(column)->GetScalar(row);
  if (!scalar.ok()) {
    throw std::runtime_error(scalar.status().ToString());
  }
  return scalar.ValueOrDie()->ToString();
}

}  // namespace tablo::test

#endif
