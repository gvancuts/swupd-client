#!/usr/bin/env bats

load "../testlib"

server_pub="$PWD/$TEST_NAME"_1/server-pub.pem
server_key="$PWD/$TEST_NAME"_1/server-key.pem
client_pub="$PWD/$TEST_NAME"_1/client-pub.pem
client_key="$PWD/$TEST_NAME"_1/client-key.pem

global_setup() {

	# Skip this test for local development because it takes a long time. To run this test locally,
	# configure swupd with --with-fallback-capaths=<path to top level of repo>/swupd_test_certificates
	# and run: TRAVIS=true make check
	if [ -z "${TRAVIS}" ]; then
		return
	fi

	create_test_environment "$TEST_NAME"

	sudo mkdir -p "$CLIENT_CERT_DIR"

	# create client/server certificates
	generate_certificate "$client_key" "$client_pub"
	generate_certificate "$server_key" "$server_pub"

	# add server pub key to trust store
	create_trusted_cacert "$server_pub"

	start_web_server -c "$client_pub" -p "$server_pub" -k "$server_key"
}

test_setup() {

	if [ -z "${TRAVIS}" ]; then
		skip "Skipping client certificate tests for local development, test runs in CI"
	fi

	# create client certificate in expected directory
	sudo cp "$client_key" "$CLIENT_CERT"
	sudo sh -c "cat $client_pub >> $CLIENT_CERT"
}

test_teardown() {

	if [ -z "${TRAVIS}" ]; then
		return
	fi

	sudo rm -f "$CLIENT_CERT"
	clean_state_dir "$TEST_NAME"
}

global_teardown() {

	if [ -z "${TRAVIS}" ]; then
		return
	fi


	destroy_test_environment "$TEST_NAME"
}

@test "list bundles with valid client cert" {

	run sudo sh -c "$SWUPD bundle-list $SWUPD_OPTS_HTTPS --all"

	assert_status_is 0
}

@test "list bundles with no client cert" {

	# remove client certificate
	sudo rm "$CLIENT_CERT"

	run sudo sh -c "$SWUPD bundle-list $SWUPD_OPTS_HTTPS --all"
	assert_status_is "$ECURL_INIT"

	expected_output=$(cat <<-EOM
			Error: unable to verify server SSL certificate
	EOM
	)
	assert_in_output "$expected_output"
}

@test "list bundles with invalid client cert" {

	# make client certificate invalid
	sudo sh -c "echo foo > $CLIENT_CERT"

	run sudo sh -c "$SWUPD bundle-list $SWUPD_OPTS_HTTPS --all"
	assert_status_is "$ECURL_INIT"

	expected_output=$(cat <<-EOM
			Curl: Problem with the local client SSL certificate
	EOM
	)
	assert_in_output "$expected_output"
}
