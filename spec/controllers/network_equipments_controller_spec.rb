# Copyright (c) 2009-2011 Cyril Rohr, INRIA Rennes - Bretagne Atlantique
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'spec_helper'

describe NetworkEquipmentsController do
  render_views

  describe "GET /network_equipments" do
    it "should get 404 in default branch" do
      get :index, :format => :json
      response.status.should == 404
    end
    
    it "should get collection in testing branch" do
      get :index, :format => :json, :branch => "testing"
      response.status.should == 200
      json['total'].should == 4
      json['items'].length.should == 4
    end

    it "should get collection in testing branch" do
      get :index, :site_id => "lille", :format => :json, :branch => "testing"
      response.status.should == 200
      json['total'].should == 6
      json['items'].length.should == 6
    end
  end # describe "GET /network_equipments"

end
