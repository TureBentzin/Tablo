#include "test_data.h"
#include "test_framework.h"

#include <worker.h>

#include <chrono>
#include <thread>
#include <variant>

namespace {

class RunningWorker {
 public:
  explicit RunningWorker(Worker& worker) : worker_(worker), thread_(&Worker::solveRequestCycle, &worker) {}

  ~RunningWorker() {
    worker_.disconnect();
    if (thread_.joinable()) {
      thread_.join();
    }
  }

 private:
  Worker& worker_;
  std::thread thread_;
};

ttp2::ServerSessionController::Packet waitForResponse(Worker& worker) {
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
  while (std::chrono::steady_clock::now() < deadline) {
    if (worker.getResponseCollectionSize() > 0) {
      return worker.getResponse();
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  throw tablo::test::Failure("worker did not produce a response within two seconds");
}

}  // namespace

TABLO_TEST("worker request queue is FIFO") {
  Worker worker;
  for (int id : {3, 1, 2}) {
    ttp2::ServerSessionController::Packet packet;
    packet.id = id;
    worker.pushRequest(packet);
  }

  TABLO_CHECK_EQ(worker.getRequestCollectionSize(), 3);
  TABLO_CHECK_EQ(worker.getRequest().id, 3);
  TABLO_CHECK_EQ(worker.getRequest().id, 1);
  TABLO_CHECK_EQ(worker.getRequest().id, 2);
  TABLO_CHECK_EQ(worker.getRequestCollectionSize(), 0);
}

TABLO_TEST("worker echoes standard packets with their request id") {
  Worker worker;
  ttp2::ServerSessionController::Packet request;
  request.id = 42;
  ttp2::ServerSessionController::Standard standard;
  standard.payload = "hello";
  request.payload = standard;
  worker.pushRequest(request);

  RunningWorker running(worker);
  auto response = waitForResponse(worker);

  TABLO_CHECK_EQ(response.id, 42);
  TABLO_CHECK(std::holds_alternative<ttp2::ServerSessionController::Standard>(response.payload));
  TABLO_CHECK_EQ(std::get<ttp2::ServerSessionController::Standard>(response.payload).payload,
                 std::string("hello"));
}

TABLO_TEST("worker serves a viewport from a transferred partition") {
  Worker worker;

  ttp2::ServerSessionController::Packet fileRequest;
  fileRequest.id = 1;
  fileRequest.payload = tablo::test::makeFile();
  worker.pushRequest(fileRequest);

  ttp2::ServerSessionController::ViewportRequest viewportRequest;
  viewportRequest.xStart = 11;
  viewportRequest.xEnd = 12;
  viewportRequest.yStart = 0;
  viewportRequest.yEnd = 1;
  ttp2::ServerSessionController::Packet request;
  request.id = 7;
  request.payload = viewportRequest;
  worker.pushRequest(request);

  RunningWorker running(worker);
  auto response = waitForResponse(worker);

  TABLO_CHECK_EQ(response.id, 7);
  TABLO_CHECK(std::holds_alternative<ttp2::ServerSessionController::Viewport>(response.payload));
  const auto& viewport = std::get<ttp2::ServerSessionController::Viewport>(response.payload);
  TABLO_CHECK_EQ(viewport.xStart, 11);
  TABLO_CHECK_EQ(viewport.xEnd, 12);
  TABLO_CHECK_EQ(viewport.payload->num_rows(), 2);
  TABLO_CHECK_EQ(tablo::test::scalarAt(viewport.payload, 0, 0), std::string("Berlin"));
}

TABLO_TEST("worker rejects reversed viewport bounds") {
  Worker worker;

  ttp2::ServerSessionController::ViewportRequest viewportRequest;
  viewportRequest.xStart = 12;
  viewportRequest.xEnd = 11;
  viewportRequest.yStart = 0;
  viewportRequest.yEnd = 1;
  ttp2::ServerSessionController::Packet request;
  request.id = 8;
  request.payload = viewportRequest;
  worker.pushRequest(request);

  RunningWorker running(worker);
  auto response = waitForResponse(worker);

  TABLO_CHECK_EQ(response.id, 8);
  TABLO_CHECK(std::holds_alternative<ttp2::ServerSessionController::Viewport>(response.payload));
  const auto& viewport = std::get<ttp2::ServerSessionController::Viewport>(response.payload);
  TABLO_CHECK_EQ(viewport.payload->num_rows(), 0);
  TABLO_CHECK_EQ(viewport.payload->num_columns(), 0);
}

TABLO_TEST("worker executes a TQL request against transferred data") {
  Worker worker;

  ttp2::ServerSessionController::Packet fileRequest;
  fileRequest.payload = tablo::test::makeFile();
  worker.pushRequest(fileRequest);

  ttp2::ServerSessionController::TqlQuery query;
  query.query = "SELECT city FROM ignored.csv WHERE score >= 30";
  ttp2::ServerSessionController::Packet request;
  request.id = 9;
  request.payload = query;
  worker.pushRequest(request);

  RunningWorker running(worker);
  auto response = waitForResponse(worker);

  TABLO_CHECK_EQ(response.id, 9);
  TABLO_CHECK(std::holds_alternative<ttp2::ServerSessionController::Viewport>(response.payload));
  const auto& viewport = std::get<ttp2::ServerSessionController::Viewport>(response.payload);
  TABLO_CHECK_EQ(viewport.payload->num_rows(), 2);
  TABLO_CHECK_EQ(tablo::test::scalarAt(viewport.payload, 0, 0), std::string("Cologne"));
  TABLO_CHECK_EQ(tablo::test::scalarAt(viewport.payload, 0, 1), std::string("Dresden"));
}
