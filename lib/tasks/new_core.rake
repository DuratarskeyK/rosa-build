namespace :new_core do
  desc 'Sets bs_id field for all BuildList which use new_core'
  task :update_bs_id => :environment do
    say "[#{Time.zone.now}] Starting to update bs_id..."

    BuildList.select(:id).
      where(:new_core => true, :bs_id => nil).
      find_in_batches(:batch_size => 500) do | bls |

      puts "[#{Time.zone.now}] - where build_lists.id from #{bls.first.id} to #{bls.last.id}"
      BuildList.where(:id => bls.map(&:id), :bs_id => nil).
        update_all("bs_id = id")
    end

    say "[#{Time.zone.now}] done"
  end

  desc 'Publish mass-build 73'
  task :publish_mass_build_73 => :environment do
    say "[#{Time.zone.now}] Starting to publish mass-build 317..."

    bl = BuildList.where(:mass_build_id => 73).first
    repository_path = "#{bl.save_to_platform.path}/repository"
    BuildList.where(:mass_build_id => 73).
      where("status != #{BuildServer::BUILD_ERROR}").
      order(:id).
      find_in_batches(:batch_size => 1) do | bls |

      bl = bls.first
      puts "[#{Time.zone.now}] - where build_lists.id #{bl.id}"

      sha1 = bl.results.find{ |r| r['file_name'] =~ /.*\.tar\.gz$/ }['sha1']

      system "cd #{repository_path} && curl -L -O http://file-store.rosalinux.ru/api/v1/file_stores/#{sha1}"
      system "cd #{repository_path} && tar -xzf #{sha1}"
      system "rm -f #{repository_path}/#{sha1}"

      archive_folder = "#{repository_path}/archives"
      system "sudo chown root:root  #{archive_folder}/SRC_RPM/*"
      system "sudo chmod 0666       #{archive_folder}/SRC_RPM/*"
      system "sudo chown root:root  #{archive_folder}/RPM/*"
      system "sudo chmod 0666       #{archive_folder}/RPM/*"

      system "sudo mv #{archive_folder}/SRC_RPM/* #{repository_path}/SRPMS/main/release/"
      system "sudo mv #{archive_folder}/RPM/*     #{repository_path}/#{bl.arch.name}/main/release/"

      system "sudo rm -rf #{archive_folder}"
      bl.update_column(:status, BuildList::BUILD_PUBLISH)
    end

    say "[#{Time.zone.now}] done"
  end

end