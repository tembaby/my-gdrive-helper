#!/usr/bin/env ruby
#
# Copyright (c) 2018 Tamer Embaby <tamer@embaby.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of this work.
#

require 'google/apis/drive_v2'
require 'google/api_client/client_secrets'
require 'launchy'
require 'optparse'

# Handle authentication client 
$__auth_client = nil
def get_auth_client()

	# Client secrets depends on the "client_secrets.json" file to exist on pre-defined paths.
	# The file must exist in the current working directory of the Ruby script.
	if $__auth_client != nil
		return $__auth_client
	end

	client_secrets = Google::APIClient::ClientSecrets.load
	auth_client = client_secrets.to_authorization
	auth_client.update!(
			:scope => 'https://www.googleapis.com/auth/drive',
			:redirect_uri => 'urn:ietf:wg:oauth:2.0:oob'
		)

	auth_uri = auth_client.authorization_uri.to_s
	Launchy.open(auth_uri)

	puts 'Paste the code from the auth response page:'
	auth_client.code = gets
	auth_client.fetch_access_token!

	$__auth_client = auth_client
	return $__auth_client
end

# XXX/FIXME This function is really slow.
def get_parent_path(file_id, drive)
	__total = ""
	file = drive.get_file(file_id)

	begin
		if file.nil?
			break
		end
		if file.parents[0]
			nxt_id = file.parents[0].id
		else
			nxt_id = nil
		end

		__total = "#{file.title}" + "/" + __total
	end while nxt_id != nil and file = drive.get_file(nxt_id)

	#puts "DEBUG> __total=[#{__total}]"
	return __total
end

def print_file_info(file: nil, file_id: nil, drive: nil)

	if file == nil and file_id == nil
		puts "Nothing to do!"
		return
	end

	# if we are passed file_id, we get file handle for it
	if file_id != nil and drive != nil
		file = drive.get_file(file_id)
		if file.nil?
			puts "ERROR: Cannot get file handle for #{file_id}"
		end
	end

	puts ">> File #{file.title} [#{file.id}]:"
	puts "   File type: [#{file.mime_type}], shared=#{file.shared},"
	puts "              editor_can_share=#{file.writers_can_share}, restricted=#{file.labels.restricted}"

	file.owners.each do |owner|
		puts "   Owned by #{owner.display_name} (#{owner.email_address}) and permission ID #{owner.permission_id}"
	end 

	#if not file.sharing_user.nil?
	#	u = file.sharing_user
	#	puts "==> SU: #{u.display_name} (#{u.email_address})"
	#end

	#p = file.user_permission
	#puts "==> P: role=[#{p.role}] type=[#{p.type}]"
	#==> P: role=[owner] type=[user]

	#file.owner_names.each do |owner|
	#	puts "==> ON: #{owner}"
	#end

	if $options[:verbose]
		# List permissions for file
		if drive != nil
			perms = drive.list_permissions(file.id)
			perms.items.each do |perm|
				puts "   P++: #{perm.id} #{perm.role} #{perm.email_address} #{perm.name} #{perm.value}"
			end
		end

		if file.permissions != nil 
			file.permissions.each do |perm|
				puts "   P+++: #{perm.id} #{perm.role} #{perm.email_address} #{perm.name} #{perm.value}"
			end
		else
			puts "   No permissions in class."
		end
		if file.permission_ids != nil
			file.permission_ids.each do |perm_id|
				puts "   #{perm_id}"
			end
		else
			puts "   No permission IDs in class."
		end

		file.parents.each do |parent|
			puts "   PARENT++: #{parent.id} #{parent.is_root} #{parent.self_link}"
			path = get_parent_path(parent.id, drive) + file.title
			puts "   PARENT++: Full path [#{path}]"
		end
		puts ""
	end
end

## Entry Point
def find_directory(dirname = nil)
	drive = Google::Apis::DriveV2::DriveService.new
	drive.authorization = get_auth_client()

	page_token = nil
	limit = 1000
	count = 0
	query = ""

	if $options[:root]
		query = "\'#{$options[:root]}\' in parents"
		puts "++ Query string [#{query}]"
	end

	begin
		files = drive.list_files(q: query,
								max_results: [limit, 100].min,
								page_token: page_token
								)

		files.items.each do |file|
			if file.mime_type == 'application/vnd.google-apps.folder'

				if dirname != nil
					__src = file.title
					__dst = dirname

					if $options[:case]
						__src = file.title.downcase
						__dst = dirname.downcase
					end

					if __src != __dst 
						next
					end
				end

				print_file_info(file: file, drive: drive)

				if $options[:apply_action] and not $options[:dry_run]
					apply_action(file, drive)
				end

			 	count += 1
			end
		end

		limit -= files.items.length
		if files.next_page_token
			page_token = files.next_page_token
		else
			page_token = nil
		end
	end while not page_token.nil? and limit > 0

	puts "++ #{count} total listed (limit=#{limit})"
end

def apply_action(file, drive)
	my_email = drive.get_about().user.email_address
	my_name = drive.get_about().user.display_name

	puts "==> ACTION: Applying actions on [#{file.title}]"

	owner = file.owners.at(0).email_address
	if owner != my_email
		puts "===> NOTICE: skipping #{file.title}: not owned by me (me(#{my_email})/them(#{owner})))"
		return
	end

	# All that can apply
	if $options[:apply_action_no_share]
		puts "===> editors cannot share or add others"
		# This works if no other action 
		file.writers_can_share = false
		drive.patch_file(file.id, file)
	end

	if $options[:apply_action_restricted]
		puts "===> viewers cannot download, print or copy"
		if file.mime_type == 'application/vnd.google-apps.folder'
			puts "===> NOTICE: skipping directory #{file.title}"
			return
		end
		file.labels.restricted = true
		drive.patch_file(file.id, file)
	end

	puts "==> ACTION: DONE"
	puts ""
end

def revoke_sharing_permissions(file, drive)
	revoke_list = nil
	me_email = ""
	me_name = ""

	my_email = drive.get_about().user.email_address
	my_name = drive.get_about().user.display_name
	puts "++ revoke_sharing_permissions: who-am-i?: [#{my_email}] [#{my_name}]"

	# We should revoke email in email list supplied in command line here
	# or delete all sharing is the list is empty (except for owner)
	puts "++ revoke_sharing_permissions: revoke target: #{file.title}"

	# Compile revoke list here: every one with sharing permission except
	# for "owner" permission and authenticated user
	perms = drive.list_permissions(file.id)
	perms.items.each do |perm|
		# P++: #{perm.id} #{perm.role} #{perm.email_address} #{perm.name} #{perm.value}
		# I will skip permission in case if:
		#   1- permission is the owner of the file
		#   2- I'm not the owner but the file/folder has been shared with me (a folder I shared, someone
		#      created a file there (they are the owner now) and they gave me permission (read/write))
		#next if perm.role == "owner" and perm.email_address == my_email
		if perm.role == "owner" or perm.email_address == my_email
			next
		end

		if !$options[:email_list].nil?
			if !$options[:email_list].include? perm.email_address
				next
			end
		end

		puts "++ >> revoke_sharing_permissions: removing #{perm.id} #{perm.role} #{perm.email_address}, \
			dry run=#{$options[:dry_run]}"
		next if $options[:dry_run]

		drive.delete_permission(file.id, perm.id)
	end
end

## Entry Point
$tr_ecount = 0
def traverse(dirid, __nested_drive = nil)

	if __nested_drive.nil?
		drive = Google::Apis::DriveV2::DriveService.new
		drive.authorization = get_auth_client()
	else
		drive = __nested_drive
	end

	page_token = nil
	count = 0
	query = ""

	file = drive.get_file(dirid)
	if file.nil?
		puts "Cannot get file handle for ID #{dirid}"
		return
	end

	if file.mime_type != 'application/vnd.google-apps.folder'
		puts "#{dirid} is not a folder (#{file.mime_type})"
		return
	end

	if __nested_drive.nil?
		puts ">> Traverse: starting with directory #{file.title} (#{dirid})"
	end

	begin
		children = drive.list_children(dirid,
								q: query,
								page_token: page_token
								)

		children.items.each do |child|
			$tr_ecount += 1
			file = drive.get_file(child.id)
			puts "+ Child [#{file.title}] [#{file.mime_type}]"
			if $options[:long_listing]
				print_file_info(file: file, drive: drive)
			end

			if $options[:revoke_sharing]
				revoke_sharing_permissions(file, drive)
			end

			if $options[:apply_action] and not $options[:dry_run]
				apply_action(file, drive)
			end

			if file.mime_type == 'application/vnd.google-apps.folder'
				puts "==> Going down to #{file.title}"
				traverse(file.id, drive)
			end
			count += 1
		end

		if children.next_page_token
			page_token = children.next_page_token
		else
			page_token = nil
		end
	end while not page_token.nil?

	if __nested_drive.nil?
		puts "++ #{count} total listed (total entities #{$tr_ecount})"
	end
end

def print_usage(opt: nil)
	puts "my-gdrive-helper.rb [action] [action-options]\n\
\tAction is one of:
\t\t--find-directory <directory-name>: Locate directory by name
\t\t--traverse <directory-id>: Traverse directory starting from directory ID
\t\t--find-user-shares: Find user shares, user list? supplied in --email"
	exit(2)
end

## Entry Point
def find_user_shares(user_list)
	drive = Google::Apis::DriveV2::DriveService.new
	drive.authorization = get_auth_client()

	page_token = nil
	query = ""

	user_list.each do |email_address|
		count = 0
		query = "\'#{email_address}\' in writers or \'#{email_address}\' in readers "

		puts "++ Query string [#{query}]" if $options[:verbose]
		puts "User: #{email_address}"
		begin
			files = drive.list_files(q: query, page_token: page_token)
			files.items.each do |file|
				if $options[:long_listing]
					print_file_info(file: file, drive: drive)
				else
					if !file.parents[0].nil?
						filepath = get_parent_path(file.parents[0].id, drive) + file.title
					else
						filepath = "<" + file.title + ">"
					end
					puts "--> #{filepath}"
				end

				if $options[:revoke_sharing]
					revoke_sharing_permissions(file, drive)
				end
				count += 1
			end
		end
		puts "(Total #{count} entries)\n\n"
	end
end

##########
## MAIN ##
##########

$options = {}
$options[:long_listing] = false
$options[:case] = false
$options[:verbose] = false
$options[:revoke_sharing] = false
$options[:dry_run] = false

OptionParser.new do |opt|
	opt.on('-d', '--find-directory DIRECTORYNAME') do |name|
		puts "+ Searching for directory name: #{name}"
		$options[:directory_name] = name
	end

	opt.on('-l', '--long') do
		puts "+ Using long listing"
		$options[:long_listing] = true
	end

	opt.on('-i', '--case-insensitive') do
		puts "+ Using case insensitive matching"
		$options[:case] = true
	end

	opt.on('-v', '--verbose') do
		puts "+ Verbose mode on"
		$options[:verbose] = true
	end

	opt.on('-r', '--root ROOT') do |root|
		puts "+ Limiting search to top level ID #{root}"
		$options[:root] = root
	end

	opt.on('-s', '--traverse DIRECTORYID') do |dirid|
		puts "+ Traversing top directory ID: #{dirid}"
		$options[:traverse] = dirid
	end

	opt.on('', '--revoke-sharing') do
		puts "+ Revoke sharing permissions on targets"
		$options[:revoke_sharing] = true
	end

	opt.on('', '--email EMAIL') do |email|
		if $options[:email_list].nil?
			$options[:email_list] = Array.new
		end
		$options[:email_list] << email
	end

	opt.on('', '--dry-run') do
		$options[:dry_run] = true
	end

	opt.on('', '--find-user-shares') do
		puts "+ Finding user shares"
		$options[:find_user_shares] = true
		# User list will come in --email <email1.com> --email <email2.com> ...
	end

	opt.on('', '--find-file FILENAME_PATTERN') do |fname|
		$options[:find_file] = fname
	end

	opt.on('', '--apply-action action') do |action|
		$options[:apply_action] = true
		# restricted: File::Labels::restircted = true (prevent users from download, print, copy file)
		# writers_can_share: File:writers_can_share = false (Prevent editors from changing access and adding new people)
		case action
		when "restricted"
			$options[:apply_action_restricted] = true
		when "no-share"
			$options[:apply_action_no_share] = true
		else
			puts "ERROR: --apply-action: invalid action #{action}"
		end
	end

end.parse!

# Start running main functions/actions
if $options[:directory_name]
	find_directory($options[:directory_name])
elsif $options[:traverse]
	traverse($options[:traverse])
elsif $options[:find_user_shares]
	if $options[:email_list].nil?
		print_usage($options)
	end
	find_user_shares($options[:email_list])
end

#########
## EOF ##
#########