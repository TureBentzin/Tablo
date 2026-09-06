#ifndef NETWORK_MANAGER_H
#define NETWORK_MANAGER_H

#include <client_session_controller.h>
#include <memory>
#include <string>
#include <thread>
#include <server_discovery.h>

#include <tablog_registry.h>
#include <tablog.h>

class NetworkManager
{
    public:
        NetworkManager(std::string interface);
        void handleClientConnection(int serverSocket, int clientSocket);

    private:
        struct Nodes {
          std::string ip = 0;
          std::shared_ptr<ttp2::ClientSessionController> node;  
        };

        std::shared_ptr<tablog::Tablog> logger = tablog::TablogRegistry::getInstance().get("Tablo-Master");
            
        std::shared_ptr<tud::ServerDiscovery> udpDiscovery;
        std::thread serverDiscoveryThread;

};

#endif
