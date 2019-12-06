require 'openssl'
require 'digest/sha1'
require 'base64'
require 'uri'

class SitemapController < ApplicationController
      
  def sitemap_root
    iv, pui_root = encrypt_sr
    respond_to do |format|
      pui_rails_root = {:iv => URI::encode(iv), :pui_root => URI::encode(pui_root)}
      format.json { render :json => pui_rails_root.to_json }
    end
  end
  
  def encrypt_sr
    # create the cipher for encrypting
    cipher = OpenSSL::Cipher::AES.new(256, :CBC)
    cipher.encrypt
    
    key = Digest::SHA256.digest("#{AppConfig[:public_user_secret]}")
    iv = cipher.random_iv
    
    # load them into the cipher
    cipher.key = key
    cipher.iv = iv
    
    # encrypt the path
    encrypted = cipher.update("#{Rails.root.to_s}")
    encrypted << cipher.final
    return Base64.encode64(iv), Base64.encode64(encrypted)
  end

end
