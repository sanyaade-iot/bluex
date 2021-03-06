defmodule DBusDiscoveryTest do
  use Bluex.DBusCase, async: false
  @moduletag dbus_server: "test/bluem-dbus/bluem-service.py"

  @behaviour Bluex.Discovery

  @dbus_name Application.get_env(:bluex, :dbus_name)
  @mock_dbus_name "org.mock"
  @dbus_mock_path "/org/mock"
  @dbus_type Application.get_env(:bluex, :bus_type)


  alias Bluex.DBusDiscovery

  test "get list of adapters" do
    {:ok, _} = DBusDiscovery.start_link(__MODULE__, [])
    adapters = DBusDiscovery.get_adapters(__MODULE__)
    refute Enum.empty?(adapters)

    hci1 = adapters["hci1"]
    assert  %{path: "/org/bluem/hci1"} = hci1
  end

  test "start discovery" do
    {:ok, _} = DBusDiscovery.start_link(__MODULE__, [])
    :ok = DBusDiscovery.start_discovery(__MODULE__)
    #TODO: check Properties to make sure it's called
  end

  test "start discovery with specific filter" do
    {:ok, _} = DBusDiscovery.start_link(__MODULE__, [])
    :ok = DBusDiscovery.start_discovery(__MODULE__, %Bluex.DiscoveryFilter{transport: "le", uuids: ["192e3e60-9065-11e6-ae22-56b6b6499611"]})
  end

  test "stop the discovery process if there is no matched adapter" do
    pid = spawn(fn ->
      {:ok, _} = DBusDiscovery.start_link(__MODULE__, [])
      :ok = DBusDiscovery.start_discovery(__MODULE__, %Bluex.DiscoveryFilter{adapters: ["hci9"]})
    end)
    assert Process.info(pid)
    Process.sleep(100)
    refute Process.info(pid), "The process should be stopped"
  end

  test "start discovery on existing adapter" do
    {:ok, _} = DBusDiscovery.start_link(__MODULE__, [])
    :ok = DBusDiscovery.start_discovery(__MODULE__, %Bluex.DiscoveryFilter{adapters: ["hci1"]})
    Process.sleep(1000)
  end


  test "call device_found callback when new device is discoverd" do
    {:ok, _} = DBusDiscovery.start_link(__MODULE__, [])
    :ok = DBusDiscovery.start_discovery(__MODULE__)
    :timer.sleep(100)


    {:ok, bus} = :dbus_bus_connection.connect(@dbus_type)
    {:ok, mock_controller} = :dbus_proxy.start_link(bus, @dbus_name, @dbus_mock_path)
    {:ok, device_dbus_path} = :dbus_proxy.call(mock_controller, @mock_dbus_name, "AddDevice", [])
    :timer.sleep(100)

    devices = DBusDiscovery.get_devices(__MODULE__)
    refute Enum.empty?(devices)
    d = List.first(devices)
    dbus_name = String.replace(d.mac_address, ":", "_")
    assert device_dbus_path =~ dbus_name
  end

  def device_found(device) do
    assert device.adapter == "hci1"
    :ok
  end

end
