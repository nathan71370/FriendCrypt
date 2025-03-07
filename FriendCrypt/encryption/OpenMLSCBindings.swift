//
//  OpenMLSCBindings.swift
//  FriendCrypt
//
//  Created by Nathan Mercier on 02/03/2025.
//

import Foundation

// Define the opaque types to match the C header
public struct GroupContext {}
public struct SignerContext {}
public struct CredentialContext {}
public struct KeyPackageContext {}
public struct WelcomeContext {}
public struct StagedWelcomeContext {}
public struct MlsMessageOutContext {}

// Define the FfiResult struct to match the C struct
public struct FfiResult {
    public var success: Bool
    public var error_message: UnsafeMutablePointer<CChar>?
}

// Declare the C functions
@_silgen_name("get_default_ciphersuite")
public func get_default_ciphersuite() -> UInt32

@_silgen_name("generate_credential")
public func generate_credential(
    _ identity: UnsafePointer<CChar>,
    _ out_credential: UnsafeMutablePointer<CredentialContext>,
    _ out_signer: UnsafeMutablePointer<SignerContext>
) -> FfiResult

@_silgen_name("free_credential")
public func free_credential(_ context: CredentialContext)

@_silgen_name("free_signer")
public func free_signer(_ context: SignerContext)

@_silgen_name("generate_key_package")
public func generate_key_package(
    _ signer: UnsafePointer<SignerContext>,
    _ credential: UnsafePointer<CredentialContext>,
    _ out_key_package: UnsafeMutablePointer<KeyPackageContext>
) -> FfiResult

@_silgen_name("free_key_package")
public func free_key_package(_ context: KeyPackageContext)

@_silgen_name("create_mls_group")
public func create_mls_group(
    _ signer: UnsafePointer<SignerContext>,
    _ credential: UnsafePointer<CredentialContext>,
    _ out_group: UnsafeMutablePointer<GroupContext>
) -> FfiResult

@_silgen_name("free_group")
public func free_group(_ context: GroupContext)

@_silgen_name("add_members")
public func add_members(
    _ group: UnsafeMutablePointer<GroupContext>,
    _ signer: UnsafePointer<SignerContext>,
    _ key_packages: UnsafePointer<UnsafePointer<KeyPackageContext>?>,
    _ key_package_count: Int,
    _ out_welcome: UnsafeMutablePointer<WelcomeContext>
) -> FfiResult

@_silgen_name("merge_pending_commit")
public func merge_pending_commit(
    _ group: UnsafeMutablePointer<GroupContext>
) -> FfiResult

@_silgen_name("export_ratchet_tree")
public func export_ratchet_tree(
    _ group: UnsafePointer<GroupContext>,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ out_len: UnsafeMutablePointer<Int>
) -> FfiResult

@_silgen_name("serialize_welcome")
public func serialize_welcome(
    _ welcome: UnsafePointer<WelcomeContext>,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ out_len: UnsafeMutablePointer<Int>
) -> FfiResult

@_silgen_name("free_welcome")
public func free_welcome(_ context: WelcomeContext)

@_silgen_name("free_buffer")
public func free_buffer(_ buffer: UnsafeMutablePointer<UInt8>, _ len: Int)

@_silgen_name("free_error_message")
public func free_error_message(_ result: FfiResult)

@_silgen_name("deserialize_welcome")
public func deserialize_welcome(
    _ data: UnsafePointer<UInt8>?,
    _ data_len: Int,
    _ out_welcome: UnsafeMutablePointer<WelcomeContext>
) -> FfiResult

@_silgen_name("create_staged_welcome")
public func create_staged_welcome(
    _ welcome: UnsafePointer<WelcomeContext>,
    _ ratchet_tree_data: UnsafePointer<UInt8>?,
    _ ratchet_tree_len: Int,
    _ out_staged_welcome: UnsafeMutablePointer<StagedWelcomeContext>
) -> FfiResult

@_silgen_name("free_staged_welcome")
public func free_staged_welcome(_ context: StagedWelcomeContext)

@_silgen_name("complete_group_join")
public func complete_group_join(
    _ staged_welcome: UnsafeMutablePointer<StagedWelcomeContext>,
    _ out_group: UnsafeMutablePointer<GroupContext>
) -> FfiResult

// New functions for encryption/decryption

@_silgen_name("encrypt_message")
public func encrypt_message(
    _ group: UnsafeMutablePointer<GroupContext>,
    _ signer: UnsafePointer<SignerContext>,
    _ message_data: UnsafePointer<UInt8>?,
    _ message_len: Int,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ out_len: UnsafeMutablePointer<Int>
) -> FfiResult

@_silgen_name("decrypt_message")
public func decrypt_message(
    _ group: UnsafeMutablePointer<GroupContext>,
    _ message_data: UnsafePointer<UInt8>?,
    _ message_len: Int,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ out_len: UnsafeMutablePointer<Int>
) -> FfiResult

@_silgen_name("send_message")
public func send_message(
    _ group: UnsafeMutablePointer<GroupContext>,
    _ message_text: UnsafePointer<CChar>,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ out_len: UnsafeMutablePointer<Int>
) -> FfiResult

@_silgen_name("serialize_key_package")
public func serialize_key_package(
    _ key_package: UnsafePointer<KeyPackageContext>,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ out_len: UnsafeMutablePointer<Int>
) -> FfiResult

@_silgen_name("deserialize_key_package")
public func deserialize_key_package(
    _ data: UnsafePointer<UInt8>?,
    _ data_len: Int,
    _ out_key_package: UnsafeMutablePointer<KeyPackageContext>
) -> FfiResult

@_silgen_name("free_message_out")
public func free_message_out(_ context: MlsMessageOutContext)


@_silgen_name("encrypt_message_with_signer")
public func encrypt_message_with_signer(
    _ group: UnsafeMutablePointer<GroupContext>,
    _ signer: UnsafePointer<SignerContext>,
    _ message_data: UnsafePointer<UInt8>?,
    _ message_len: Int,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ out_len: UnsafeMutablePointer<Int>
) -> FfiResult
