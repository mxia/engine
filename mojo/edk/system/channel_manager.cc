// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "mojo/edk/system/channel_manager.h"

#include <utility>

#include "base/bind.h"
#include "base/bind_helpers.h"
#include "mojo/edk/system/channel.h"
#include "mojo/edk/system/channel_endpoint.h"
#include "mojo/edk/system/message_pipe_dispatcher.h"

namespace mojo {
namespace system {

namespace {

// TODO(vtl): |channel| should be an rvalue reference, but that currently
// doesn't work with base::Bind.
void ShutdownChannelHelper(
    RefPtr<Channel> channel,
    const base::Closure& callback,
    embedder::PlatformTaskRunnerRefPtr callback_thread_task_runner) {
  channel->Shutdown();
  if (callback_thread_task_runner) {
    embedder::PlatformPostTask(callback_thread_task_runner.get(), callback);
  } else {
    callback.Run();
  }
}

}  // namespace

ChannelManager::ChannelManager(
    embedder::PlatformSupport* platform_support,
    embedder::PlatformTaskRunnerRefPtr io_thread_task_runner,
    ConnectionManager* connection_manager)
    : platform_support_(platform_support),
      io_thread_task_runner_(io_thread_task_runner),
      connection_manager_(connection_manager) {
  DCHECK(platform_support_);
  DCHECK(io_thread_task_runner_);
  // (|connection_manager_| may be null.)
}

ChannelManager::~ChannelManager() {
  // |Shutdown()| must be called before destruction and have been completed.
  // TODO(vtl): This doesn't verify the above condition very strictly at all
  // (e.g., we may never have had any channels, or we may have manually shut all
  // the channels down).
  DCHECK(channels_.empty());
}

void ChannelManager::ShutdownOnIOThread() {
  // Taking this lock really shouldn't be necessary, but we do it for
  // consistency.
  ChannelIdToChannelMap channels;
  {
    MutexLocker locker(&mutex_);
    channels.swap(channels_);
  }

  for (auto& channel : channels)
    channel.second->Shutdown();
}

void ChannelManager::Shutdown(
    const base::Closure& callback,
    embedder::PlatformTaskRunnerRefPtr callback_thread_task_runner) {
  embedder::PlatformPostTask(
      io_thread_task_runner_.get(),
      base::Bind(&ChannelManager::ShutdownHelper, base::Unretained(this),
                 callback, callback_thread_task_runner));
}

RefPtr<MessagePipeDispatcher> ChannelManager::CreateChannelOnIOThread(
    ChannelId channel_id,
    embedder::ScopedPlatformHandle platform_handle) {
  RefPtr<ChannelEndpoint> bootstrap_channel_endpoint;
  auto dispatcher = MessagePipeDispatcher::CreateRemoteMessagePipe(
      &bootstrap_channel_endpoint);
  CreateChannelOnIOThreadHelper(channel_id, platform_handle.Pass(),
                                std::move(bootstrap_channel_endpoint));
  return dispatcher;
}

RefPtr<Channel> ChannelManager::CreateChannelWithoutBootstrapOnIOThread(
    ChannelId channel_id,
    embedder::ScopedPlatformHandle platform_handle) {
  return CreateChannelOnIOThreadHelper(channel_id, platform_handle.Pass(),
                                       nullptr);
}

RefPtr<MessagePipeDispatcher> ChannelManager::CreateChannel(
    ChannelId channel_id,
    embedder::ScopedPlatformHandle platform_handle,
    const base::Closure& callback,
    embedder::PlatformTaskRunnerRefPtr callback_thread_task_runner) {
  DCHECK(!callback.is_null());
  // (|callback_thread_task_runner| may be null.)

  RefPtr<ChannelEndpoint> bootstrap_channel_endpoint;
  auto dispatcher = MessagePipeDispatcher::CreateRemoteMessagePipe(
      &bootstrap_channel_endpoint);
  embedder::PlatformPostTask(
      io_thread_task_runner_.get(),
      base::Bind(&ChannelManager::CreateChannelHelper, base::Unretained(this),
                 channel_id, base::Passed(&platform_handle),
                 base::Passed(&bootstrap_channel_endpoint), callback,
                 callback_thread_task_runner));
  return dispatcher;
}

RefPtr<Channel> ChannelManager::GetChannel(ChannelId channel_id) const {
  MutexLocker locker(&mutex_);
  auto it = channels_.find(channel_id);
  DCHECK(it != channels_.end());
  return it->second;
}

void ChannelManager::WillShutdownChannel(ChannelId channel_id) {
  GetChannel(channel_id)->WillShutdownSoon();
}

void ChannelManager::ShutdownChannelOnIOThread(ChannelId channel_id) {
  RefPtr<Channel> channel;
  {
    MutexLocker locker(&mutex_);
    auto it = channels_.find(channel_id);
    DCHECK(it != channels_.end());
    channel = std::move(it->second);
    channels_.erase(it);
  }
  channel->Shutdown();
}

void ChannelManager::ShutdownChannel(
    ChannelId channel_id,
    const base::Closure& callback,
    embedder::PlatformTaskRunnerRefPtr callback_thread_task_runner) {
  RefPtr<Channel> channel;
  {
    MutexLocker locker(&mutex_);
    auto it = channels_.find(channel_id);
    DCHECK(it != channels_.end());
    channel.swap(it->second);
    channels_.erase(it);
  }
  channel->WillShutdownSoon();
  embedder::PlatformPostTask(
      io_thread_task_runner_.get(),
      base::Bind(&ShutdownChannelHelper, base::Passed(&channel), callback,
                 callback_thread_task_runner));
}

void ChannelManager::ShutdownHelper(
    const base::Closure& callback,
    embedder::PlatformTaskRunnerRefPtr callback_thread_task_runner) {
  ShutdownOnIOThread();
  if (callback_thread_task_runner)
    embedder::PlatformPostTask(callback_thread_task_runner.get(), callback);
  else
    callback.Run();
}

RefPtr<Channel> ChannelManager::CreateChannelOnIOThreadHelper(
    ChannelId channel_id,
    embedder::ScopedPlatformHandle platform_handle,
    RefPtr<ChannelEndpoint>&& bootstrap_channel_endpoint) {
  DCHECK_NE(channel_id, kInvalidChannelId);
  DCHECK(platform_handle.is_valid());

  // Create and initialize a |Channel|.
  auto channel = MakeRefCounted<Channel>(platform_support_);
  channel->Init(RawChannel::Create(platform_handle.Pass()));
  if (bootstrap_channel_endpoint)
    channel->SetBootstrapEndpoint(std::move(bootstrap_channel_endpoint));

  {
    MutexLocker locker(&mutex_);
    CHECK(channels_.find(channel_id) == channels_.end());
    channels_[channel_id] = channel;
  }
  channel->SetChannelManager(this);
  return channel;
}

void ChannelManager::CreateChannelHelper(
    ChannelId channel_id,
    embedder::ScopedPlatformHandle platform_handle,
    RefPtr<ChannelEndpoint> bootstrap_channel_endpoint,
    const base::Closure& callback,
    embedder::PlatformTaskRunnerRefPtr callback_thread_task_runner) {
  CreateChannelOnIOThreadHelper(channel_id, platform_handle.Pass(),
                                std::move(bootstrap_channel_endpoint));
  if (callback_thread_task_runner)
    embedder::PlatformPostTask(callback_thread_task_runner.get(), callback);
  else
    callback.Run();
}

}  // namespace system
}  // namespace mojo
