import { Announcement as AnnouncementEvent } from "../generated/Contract/Contract";
import { Announcement } from "../generated/schema";

export function handleAnnouncement(event: AnnouncementEvent): void {
  let entity = new Announcement(event.params.receiver);
  entity.receiver = event.params.receiver;
  entity.amount = event.params.amount;
  entity.tokenAddress = event.params.tokenAddress;
  entity.businessTokenAddress = event.params.businessTokenAddress;
  entity.pkx = event.params.pkx;
  entity.ciphertext = event.params.ciphertext;

  entity.save();
}
