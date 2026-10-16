require "test_helper"

class User::AvatarableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def upload(name, type)
    Rack::Test::UploadedFile.new(file_fixture(name), type)
  end

  test "stores a small square webp with the photo's metadata removed" do
    assert @user.update(avatar_upload: upload("photo.jpg", "image/jpeg"))

    assert @user.avatar.attached?
    assert_equal "image/webp", @user.avatar.content_type

    stored = @user.avatar.open { |file| Vips::Image.new_from_file(file.path) }
    assert_equal [ 256, 256 ], [ stored.width, stored.height ]
    assert_empty stored.get_fields.grep(/exif|xmp|iptc/), "camera and location details are thrown away"
  end

  test "rejects files that aren't pictures" do
    assert_not @user.update(avatar_upload: upload("notes.txt", "image/png"))
    assert_includes @user.errors[:avatar], "needs to be a photo or picture"
    assert_not @user.reload.avatar.attached?
  end

  test "a file that looks like a photo but won't open isn't saved" do
    broken = Tempfile.new([ "broken", ".jpg" ]).tap { |file| file.binmode.write("\xFF\xD8\xFF\xE0".b + "not really a photo" * 20).then { file.rewind } }

    assert_not @user.update(name: "Ada", avatar_upload: Rack::Test::UploadedFile.new(broken.path, "image/jpeg"))
    assert_includes @user.errors[:avatar], "couldn't be read. Try a different picture"
    assert_not @user.reload.avatar.attached?
    assert_nil @user.name, "nothing else is saved either"
  end

  test "rejects text pretending to be an upload" do
    assert_not @user.update(avatar_upload: "photo.jpg")
    assert_not @user.avatar.attached?
  end

  test "can be removed" do
    @user.update!(avatar_upload: upload("photo.jpg", "image/jpeg"))
    @user.update!(remove_avatar: true)
    assert_not @user.reload.avatar.attached?
  end

  test "a new picture wins over removing the old one" do
    @user.update!(avatar_upload: upload("photo.jpg", "image/jpeg"))
    @user.update!(avatar_upload: upload("photo.jpg", "image/jpeg"), remove_avatar: true)
    assert @user.reload.avatar.attached?
  end

  test "without a picture: the username's first letter on a neon colour" do
    assert_equal "A", @user.avatar_letter
    assert_includes User::Avatarable::COLOURS, @user.avatar_colour
    assert_equal "?", User.new.avatar_letter
  end
end
