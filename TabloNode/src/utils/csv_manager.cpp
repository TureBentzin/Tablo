#include "csv_manager.h"

#include <arrow/table.h>

#include <execution_endpoint.h>
#include <interpreter.h>
#include <lexer.h>
#include <parser.h>

#include <memory>

#include <server_session_controller.h>
#include <tablog.h>

#include <iostream>
#include <algorithm>
#include <numeric>
#include <string>

void CsvManager::setFile(ttp2::ServerSessionController::File newFile) {
  this->file = newFile;
  logger->log(tablog::DEBUG, "File" + this->file.payload->ToString());
}

std::string CsvManager::getFilePath() {
  return this->file.filePath;
}

int CsvManager::getRowCount() {
  return this->file.payload->num_rows();
}

int CsvManager::getColumnCount() {
  return this->file.payload->num_columns();
}

std::shared_ptr<arrow::ChunkedArray> CsvManager::getColumnByIndex(int index) {
  return this->file.payload->column(index);
}

std::shared_ptr<arrow::Table> CsvManager::getViewport(int xStart, int xEnd, int yStart, int yEnd) {  
  const int lastColumn = this->file.payload->num_columns() - 1;
  xStart = std::max(xStart, this->file.start);
  xEnd = std::min(xEnd, this->file.end);
  yStart = std::max(yStart, 0);
  yEnd = std::min(yEnd, lastColumn);

  if (xStart > xEnd || yStart > yEnd) {
    return arrow::Table::Make(arrow::schema({}), std::vector<std::shared_ptr<arrow::Array>>{}, 0);
  }

  logger->log(tablog::DEBUG, "yStart " + std::to_string(yStart) + " yEnd " + std::to_string(yEnd));

  const int localRowStart = xStart - this->file.start;
  const int rowCount = xEnd - xStart + 1;
  logger->log(tablog::DEBUG, "xStart " + std::to_string(localRowStart) + " rowCount " + std::to_string(rowCount));
  
  // Slice columns
  std::vector<int> selectColumnIndices(yEnd - yStart + 1);
  std::iota(selectColumnIndices.begin(), selectColumnIndices.end(), yStart);
  std::shared_ptr<arrow::Table> columnSliceTable = *this->file.payload->SelectColumns(selectColumnIndices);

  // Slice rows
  std::shared_ptr<arrow::Table> slicedRowTable = columnSliceTable->Slice(localRowStart, rowCount);

  // logger->log(tablog::DEBUG, "Viewport content:\n" + slicedRowTable->ToString());
  
  return slicedRowTable;
}

std::shared_ptr<arrow::Table> CsvManager::executeQuery(const std::string& query) {
  tql::Lexer lexer;
  lexer.tokenize(query);

  tql::Parser parser;
  tql::Parser::Expression expression = parser.parse(lexer);

  tql::ExecutionEndpoint executionEndpoint;
  tql::Interpreter interpreter;

  // The file was already transferred to this node. Ignore the path in the
  // query and run all operations against this node's in-memory partition.
  interpreter.setOpenFile([this](std::string) {
    return this->file.payload;
  });
  interpreter.setGetWhere([&executionEndpoint](std::string operatorName, std::string columnName,
                                               std::string compareValue, std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.getWhere(operatorName, columnName, compareValue, table);
  });
  interpreter.setSelectColumns([&executionEndpoint](std::vector<std::string> columnNames,
                                                     std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.selectColumns(columnNames, table);
  });
  interpreter.setGetDistinct([&executionEndpoint](std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.getDistinct(table);
  });
  interpreter.setGetCount([&executionEndpoint](std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.getCount(table);
  });
  interpreter.setGetMin([&executionEndpoint](std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.getMin(table);
  });
  interpreter.setGetMax([&executionEndpoint](std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.getMax(table);
  });
  interpreter.setGetSum([&executionEndpoint](std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.getSum(table);
  });
  interpreter.setGetAvg([&executionEndpoint](std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.getAvg(table);
  });
  interpreter.setGetRenamedTable([&executionEndpoint](std::string originalColumnName,
                                                       std::string newColumnName,
                                                       std::shared_ptr<arrow::Table> table) {
    return executionEndpoint.getRenamedTable(originalColumnName, newColumnName, table);
  });

  return interpreter.interpret(expression);
}
