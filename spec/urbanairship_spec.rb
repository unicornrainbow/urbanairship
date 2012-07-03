describe Urbanairship do
  before(:all) do
    FakeWeb.allow_net_connect = false

    # register_device
    FakeWeb.register_uri(:put, "https://my_app_key:my_app_secret@go.urbanairship.com/api/apids/new_device_token", :status => ["201", "Created"])
    FakeWeb.register_uri(:put, "https://my_app_key:my_app_secret@go.urbanairship.com/api/device_tokens/new_device_token", :status => ["201", "Created"])
    FakeWeb.register_uri(:put, "https://my_app_key:my_app_secret@go.urbanairship.com/api/device_tokens/existing_device_token", :status => ["200", "OK"])
    FakeWeb.register_uri(:put, "https://my_app_key:my_app_secret@go.urbanairship.com/api/device_tokens/device_token_one", :status => ["201", "Created"])
    FakeWeb.register_uri(:put, /bad_key\:my_app_secret\@go\.urbanairship\.com/, :status => ["401", "Unauthorized"])

    # unregister_device
    FakeWeb.register_uri(:delete, /my_app_key\:my_app_secret\@go\.urbanairship.com\/api\/apids\/.+/, :status => ["204", "No Content"])
    FakeWeb.register_uri(:delete, /my_app_key\:my_app_secret\@go\.urbanairship.com\/api\/device_tokens\/.+/, :status => ["204", "No Content"])
    FakeWeb.register_uri(:delete, /bad_key\:my_app_secret\@go\.urbanairship.com\/api\/device_tokens\/.+/, :status => ["401", "Unauthorized"])

    # push
    FakeWeb.register_uri(:post, "https://my_app_key:my_master_secret@go.urbanairship.com/api/push/", :status => ["200", "OK"])
    FakeWeb.register_uri(:post, "https://my_app_key2:my_master_secret2@go.urbanairship.com/api/push/", :status => ["400", "Bad Request"])
    FakeWeb.register_uri(:post, /bad_key\:my_master_secret\@go\.urbanairship\.com/, :status => ["401", "Unauthorized"])

    # batch_push
    FakeWeb.register_uri(:post, "https://my_app_key:my_master_secret@go.urbanairship.com/api/push/batch/", :status => ["200", "OK"])
    FakeWeb.register_uri(:post, "https://my_app_key2:my_master_secret2@go.urbanairship.com/api/push/batch/", :status => ["400", "Bad Request"])

    # broadcast push
    FakeWeb.register_uri(:post, "https://my_app_key:my_master_secret@go.urbanairship.com/api/push/broadcast/", :status => ["200", "OK"])
    FakeWeb.register_uri(:post, "https://my_app_key2:my_master_secret2@go.urbanairship.com/api/push/broadcast/", :status => ["400", "Bad Request"])

    # delete_scheduled_push
    FakeWeb.register_uri(:delete, /my_app_key\:my_master_secret\@go\.urbanairship.com\/api\/push\/scheduled\/[0-9]+/, :status => ["204", "No Content"])
    FakeWeb.register_uri(:delete, /my_app_key\:my_master_secret\@go\.urbanairship.com\/api\/push\/scheduled\/alias\/.+/, :status => ["204", "No Content"])
    FakeWeb.register_uri(:delete, /bad_key\:my_master_secret\@go\.urbanairship.com\/api\/push\/scheduled\/[0-9]+/, :status => ["401", "Unauthorized"])

    # feedback
    FakeWeb.register_uri(:get, /my_app_key\:my_master_secret\@go\.urbanairship.com\/api\/device_tokens\/feedback/, :status => ["200", "OK"], :body => "[{\"device_token\":\"token\",\"marked_inactive_on\":\"2010-10-14T19:15:13Z\",\"alias\":\"my_alias\"}]")
    FakeWeb.register_uri(:get, /my_app_key2\:my_master_secret2\@go\.urbanairship.com\/api\/device_tokens\/feedback/, :status => ["500", "Internal Server Error"])
    @urbanairship = Urbanairship.new
  end

  describe "configuration" do
    it "enables you to configure the application key" do
      @urbanairship.application_key.should be_nil
      @urbanairship.application_key = "asdf1234"
      @urbanairship.application_key.should == "asdf1234"
    end

    it "enables you to configure the application secret" do
      @urbanairship.application_secret.should be_nil
      @urbanairship.application_secret = "asdf1234"
      @urbanairship.application_secret.should == "asdf1234"
    end

    it "enables you to configure the master secret" do
      @urbanairship.master_secret.should be_nil
      @urbanairship.master_secret = "asdf1234"
      @urbanairship.master_secret.should == "asdf1234"
    end
  end

  describe "::register_device" do
    before(:each) do
      @valid_params = {:alias => 'one'}
      @urbanairship.application_key = "my_app_key"
      @urbanairship.application_secret = "my_app_secret"
    end

    it "raises an error if call is made without an app key and secret configured" do
      @urbanairship.application_key = nil
      @urbanairship.application_secret = nil

      lambda {
        @urbanairship.register_device("asdf1234")
      }.should raise_error(RuntimeError, "Must configure application_key, application_secret before making this request.")
    end

    it "uses app key and secret to sign the request" do
      @urbanairship.register_device("new_device_token")
      FakeWeb.last_request['authorization'].should == "Basic #{Base64::encode64('my_app_key:my_app_secret').chomp}"
    end

    it "takes and sends a device token" do
      @urbanairship.register_device("new_device_token")
      FakeWeb.last_request.path.should == "/api/device_tokens/new_device_token"
    end

    it "returns true when the device is registered for the first time" do
      @urbanairship.register_device("new_device_token").success?.should == true
    end

    it "returns true when the device is registered again" do
      @urbanairship.register_device("existing_device_token").success?.should == true
    end

    it "returns false when the authorization is invalid" do
      @urbanairship.application_key = "bad_key"
      @urbanairship.register_device("new_device_token").success?.should == false
    end

    it "accepts an alias" do
      @urbanairship.register_device("device_token_one", @valid_params).success?.should == true
    end

    it "adds alias to the JSON payload" do
      @urbanairship.register_device("device_token_one", @valid_params)
      request_json['alias'].should == "one"
    end

    it "converts alias param to string" do
      @urbanairship.register_device("device_token_one", :alias => 11)
      request_json['alias'].should be_a_kind_of String
    end

    it "uses the iOS interface by default" do
      @urbanairship.register_device("new_device_token")
      FakeWeb.last_request.path.should == "/api/device_tokens/new_device_token"
    end

    it "uses the android interface if 'provider' configuration option is set to :android" do
      @urbanairship.provider = :android
      @urbanairship.register_device("new_device_token")
      FakeWeb.last_request.path.should == "/api/apids/new_device_token"
      @urbanairship.provider = nil
    end

    it "uses the android interface if 'provider' option is passed as :android" do
      @urbanairship.register_device("new_device_token", :provider => :android)
      FakeWeb.last_request.path.should == "/api/apids/new_device_token"
    end
  end

  describe "::unregister_device" do
    before(:each) do
      @urbanairship.application_key = "my_app_key"
      @urbanairship.application_secret = "my_app_secret"
    end

    it "raises an error if call is made without an app key and secret configured" do
      @urbanairship.application_key = nil
      @urbanairship.application_secret = nil

      lambda {
        @urbanairship.unregister_device("asdf1234")
      }.should raise_error(RuntimeError, "Must configure application_key, application_secret before making this request.")
    end

    it "uses app key and secret to sign the request" do
      @urbanairship.unregister_device("key_to_delete")
      FakeWeb.last_request['authorization'].should == "Basic #{Base64::encode64('my_app_key:my_app_secret').chomp}"
    end

    it "sends the key that needs to be deleted" do
      @urbanairship.unregister_device("key_to_delete")
      FakeWeb.last_request.path.should == "/api/device_tokens/key_to_delete"
    end

    it "returns true when the device is successfully unregistered" do
      @urbanairship.unregister_device("key_to_delete").success?.should == true
      FakeWeb.last_request.body.should be_nil
    end

    it "returns false when the authorization is invalid" do
      @urbanairship.application_key = "bad_key"
      @urbanairship.unregister_device("key_to_delete").success?.should == false
    end
  end

  describe "::delete_scheduled_push" do
    before(:each) do
      @urbanairship.application_key = "my_app_key"
      @urbanairship.master_secret = "my_master_secret"
    end

    it "raises an error if call is made without an app key and master secret configured" do
      @urbanairship.application_key = nil
      @urbanairship.master_secret = nil

      lambda {
        @urbanairship.delete_scheduled_push("123456789")
      }.should raise_error(RuntimeError, "Must configure application_key, master_secret before making this request.")
    end

    it "uses app key and secret to sign the request" do
      @urbanairship.delete_scheduled_push("123456789")
      FakeWeb.last_request['authorization'].should == "Basic #{Base64::encode64('my_app_key:my_master_secret').chomp}"
    end

    it "sends the key that needs to be deleted" do
      @urbanairship.delete_scheduled_push("123456789")
      FakeWeb.last_request.path.should == "/api/push/scheduled/123456789"
    end

    it "sends the key that needs to be deleted" do
      @urbanairship.delete_scheduled_push(123456789)
      FakeWeb.last_request.path.should == "/api/push/scheduled/123456789"
    end

    it "sends the alias that needs to be deleted" do
      @urbanairship.delete_scheduled_push(:alias => "alias_to_delete")
      FakeWeb.last_request.path.should == "/api/push/scheduled/alias/alias_to_delete"
    end

    it "returns true when the push notification is successfully deleted" do
      @urbanairship.delete_scheduled_push("123456789").success?.should == true
      FakeWeb.last_request.body.should be_nil
    end

    it "returns false when the authorization is invalid" do
      @urbanairship.application_key = "bad_key"
      @urbanairship.delete_scheduled_push("123456789").success?.should == false
    end
  end

  describe "::push" do
    before(:each) do
      @valid_params = {:device_tokens => ['device_token_one', 'device_token_two'], :aps => {:alert => 'foo'}}
      @urbanairship.application_key = "my_app_key"
      @urbanairship.master_secret = "my_master_secret"
    end

    it "raises an error if call is made without an app key and master secret configured" do
      @urbanairship.application_key = nil
      @urbanairship.master_secret = nil

      lambda {
        @urbanairship.push(@valid_params)
      }.should raise_error(RuntimeError, "Must configure application_key, master_secret before making this request.")
    end

    it "uses app key and secret to sign the request" do
      @urbanairship.push(@valid_params)
      FakeWeb.last_request['authorization'].should == "Basic #{Base64::encode64('my_app_key:my_master_secret').chomp}"
    end

    it "returns true when it successfully pushes a notification" do
      @urbanairship.push(@valid_params).success?.should == true
    end

    it "returns false when the authorization is invalid" do
      @urbanairship.application_key = "bad_key"
      @urbanairship.push(@valid_params).success?.should == false
    end

    it "adds schedule_for to the JSON payload" do
      time = Time.parse("Oct 17th, 2010, 8:00 PM UTC")
      @urbanairship.push(@valid_params.merge(:schedule_for => [time]))
      request_json['schedule_for'].should == ['2010-10-17T20:00:00Z']
    end

    it "only attempts to format schedule_for if it is a time object" do
      @urbanairship.push(@valid_params.merge(:schedule_for => ["2010-10-10 09:09:09 UTC"]))
      request_json['schedule_for'].should == ['2010-10-10T09:09:09Z']
    end

    it "returns false if @urbanairship responds with a non-200 response" do
      @urbanairship.application_key = "my_app_key2"
      @urbanairship.master_secret = "my_master_secret2"
      @urbanairship.push.success?.should == false
    end
  end

  describe "::batch_push" do
    before(:each) do
      @valid_params = [
        {:device_tokens => ['device_token_one', 'device_token_two'], :aps => {:alert => 'foo'}},
        {:device_tokens => ['device_token_three', 'device_token_four'], :aps => {:alert => 'bar'}}
      ]
      @urbanairship.application_key = "my_app_key"
      @urbanairship.master_secret = "my_master_secret"
    end

    it "raises an error if call is made without an app key and master secret configured" do
      @urbanairship.application_key = nil
      @urbanairship.master_secret = nil

      lambda {
        @urbanairship.batch_push(@valid_params)
      }.should raise_error(RuntimeError, "Must configure application_key, master_secret before making this request.")
    end

    it "uses app key and secret to sign the request" do
      @urbanairship.batch_push(@valid_params)
      FakeWeb.last_request['authorization'].should == "Basic #{Base64::encode64('my_app_key:my_master_secret').chomp}"
    end

    it "returns true when it successfully pushes a notification" do
      @urbanairship.batch_push(@valid_params).success?.should == true
    end

    it "returns false when the authorization is invalid" do
      @urbanairship.application_key = "bad_key"
      @urbanairship.batch_push(@valid_params).success?.should == false
    end

    it "adds schedule_for to the JSON payload" do
      time = Time.parse("Oct 17th, 2010, 8:00 PM UTC")
      @valid_params[0].merge!(:schedule_for => [time])
      @urbanairship.batch_push(@valid_params)
      request_json[0]['schedule_for'].should == ['2010-10-17T20:00:00Z']
    end

    it "accepts strings as schedule_for values" do
      @valid_params[0].merge!(:schedule_for => ["2010-10-10 09:09:09 UTC"])
      @urbanairship.batch_push(@valid_params)
      request_json[0]['schedule_for'].should == ['2010-10-10T09:09:09Z']
    end

    it "returns false if @urbanairship responds with a non-200 response" do
      @urbanairship.application_key = "my_app_key2"
      @urbanairship.master_secret = "my_master_secret2"
      @urbanairship.batch_push.success?.should == false
    end
  end

  describe "::broadcast_push" do
    before(:each) do
      @valid_params = {:aps => {:alert => 'foo'}}
      @urbanairship.application_key = "my_app_key"
      @urbanairship.master_secret = "my_master_secret"
    end

    it "raises an error if call is made without an app key and master secret configured" do
      @urbanairship.application_key = nil
      @urbanairship.master_secret = nil

      lambda {
        @urbanairship.broadcast_push(@valid_params)
      }.should raise_error(RuntimeError, "Must configure application_key, master_secret before making this request.")
    end

    it "uses app key and secret to sign the request" do
      @urbanairship.broadcast_push(@valid_params)
      FakeWeb.last_request['authorization'].should == "Basic #{Base64::encode64('my_app_key:my_master_secret').chomp}"
    end

    it "returns true when it successfully pushes a notification" do
      @urbanairship.broadcast_push(@valid_params).success?.should == true
    end

    it "returns false when the authorization is invalid" do
      @urbanairship.application_key = "bad_key"
      @urbanairship.broadcast_push(@valid_params).success?.should == false
    end

    it "adds schedule_for to the JSON payload" do
      time = Time.parse("Oct 17th, 2010, 8:00 PM UTC")
      @valid_params[:schedule_for] = [time]
      @urbanairship.broadcast_push(@valid_params)
      request_json['schedule_for'].should == ['2010-10-17T20:00:00Z']
    end

    it "accepts strings as schedule_for values" do
      @valid_params[:schedule_for] = ["2010-10-10 09:09:09 UTC"]
      @urbanairship.broadcast_push(@valid_params)
      request_json['schedule_for'].should == ['2010-10-10T09:09:09Z']
    end

    it "returns false if @urbanairship responds with a non-200 response" do
      @urbanairship.application_key = "my_app_key2"
      @urbanairship.master_secret = "my_master_secret2"
      @urbanairship.broadcast_push.success?.should == false
    end
  end

  describe "::feedback" do
    before(:each) do
      @urbanairship.application_key = "my_app_key"
      @urbanairship.master_secret = "my_master_secret"
    end

    it "raises an error if call is made without an app key and master secret configured" do
      @urbanairship.application_key = nil
      @urbanairship.master_secret = nil

      lambda {
        @urbanairship.feedback(Time.now)
      }.should raise_error(RuntimeError, "Must configure application_key, master_secret before making this request.")
    end

    it "uses app key and secret to sign the request" do
      @urbanairship.feedback(Time.now)
      FakeWeb.last_request['authorization'].should == "Basic #{Base64::encode64('my_app_key:my_master_secret').chomp}"
    end

    it "encodes the time argument in UTC, ISO 8601 format" do
      time = Time.parse("October 10, 2010, 8:00pm")
      formatted_time = time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      @urbanairship.feedback(time)
      FakeWeb.last_request.path.should include(formatted_time)
    end

    it "accepts a string as the time argument" do
      @urbanairship.feedback("Oct 07, 2010 8:00AM UTC")
      FakeWeb.last_request.path.should include("2010-10-07T08:00:00Z")
    end

    it "returns an array of responses from the feedback API" do
      response = @urbanairship.feedback(Time.now)
      response[0].should include("device_token")
      response[0].should include("marked_inactive_on")
      response[0].should include("alias")
    end

    it "success? is false when the call doesn't return 200" do
      @urbanairship.application_key = "my_app_key2"
      @urbanairship.master_secret = "my_master_secret2"
      @urbanairship.feedback(Time.now).success?.should == false
    end
  end

  describe "logging" do

    before(:each) do
      @logger = mock("logger", :info => true)
      @urbanairship.application_key = "my_app_key"
      @urbanairship.application_secret = "my_app_secret"
      @urbanairship.master_secret = "my_master_secret"
      @urbanairship.logger = @logger
    end

    it "logs request and response information when registering a device" do
      @logger.should_receive(:info).with(/\/api\/device_tokens\/new_device_token/)
      @urbanairship.register_device('new_device_token')
    end

    it "logs request and response information when sending push notifications" do
      @logger.should_receive(:info).with(/\/api\/push/)
      @urbanairship.push(:device_tokens => ["device_token"], :aps => {:alert => "foo"})
    end

    it "logs request and response information when sending batch push notifications" do
      @logger.should_receive(:info).with(/\/api\/push\/batch/)
      @urbanairship.batch_push([:device_tokens => ["device_token"], :aps => {:alert => "foo"}])
    end

    it "logs request and response information when sending feedback requests" do
      @logger.should_receive(:info).with(/\/api\/device_tokens\/feedback/)
      @urbanairship.feedback(Time.now)
    end

    it "flushes the logger buffer if it's an ActiveSupport::BufferedLogger (Default Rails logger)" do
      @logger.stub(:flush).and_return("message in the buffer\n")
      @logger.should_receive(:flush)
      @urbanairship.feedback(Time.now)
    end
  end

  describe "request timeout" do
    before(:each) do
      @logger = mock("logger", :info => true)
      @urbanairship.application_key = "my_app_key"
      @urbanairship.application_secret = "my_app_secret"
      @urbanairship.master_secret = "my_master_secret"
      @urbanairship.logger = @logger
    end

    it "uses a default request_timeout value of five seconds" do
      Urbanairship::Timer.should_receive(:timeout).with(5.0).and_raise(Timeout::Error)
      @logger.should_receive(:error).with(/Urbanairship request timed out/)

      @urbanairship.register_device('new_device_token')
    end

    it "accepts a configured request_timeout value" do
      Urbanairship::Timer.should_receive(:timeout).with(1.23).and_raise(Timeout::Error)
      @logger.should_receive(:error).with(/Urbanairship request timed out/)

      @urbanairship.request_timeout = 1.23
      @urbanairship.register_device('new_device_token')
    end
  end
end

def request_json
  JSON.parse FakeWeb.last_request.body
end
