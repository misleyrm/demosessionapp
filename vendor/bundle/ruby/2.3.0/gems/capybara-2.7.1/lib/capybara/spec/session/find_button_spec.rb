# frozen_string_literal: true
Capybara::SpecHelper.spec '#find_button' do
  before do
    @session.visit('/form')
  end

  it "should find any button" do
    expect(@session.find_button('med')[:id]).to eq("mediocre")
    expect(@session.find_button('crap321').value).to eq("crappy")
  end

  it "casts to string" do
    expect(@session.find_button(:'med')[:id]).to eq("mediocre")
  end

  it "should raise error if the button doesn't exist" do
    expect do
      @session.find_button('Does not exist')
    end.to raise_error(Capybara::ElementNotFound)
  end

  context "with :exact option" do
    it "should accept partial matches when false" do
      expect(@session.find_button('What an Awesome', :exact => false)[:value]).to eq("awesome")
    end

    it "should not accept partial matches when true" do
      expect do
        @session.find_button('What an Awesome', :exact => true)
      end.to raise_error(Capybara::ElementNotFound)
    end
  end

  context "with :disabled option" do
    it "should find disabled buttons when true" do
      expect(@session.find_button('Disabled button', :disabled => true).value).to eq("Disabled button")
    end

    it "should not find disabled buttons when false" do
      expect do
        @session.find_button('Disabled button', :disabled => false)
      end.to raise_error(Capybara::ElementNotFound)
    end

    it "should default to not finding disabled buttons" do
      expect do
        @session.find_button('Disabled button')
      end.to raise_error(Capybara::ElementNotFound)
    end

    it "should find disabled buttons when :all" do
      expect(@session.find_button('Disabled button', :disabled => :all).value).to eq("Disabled button")
    end
  end
end
