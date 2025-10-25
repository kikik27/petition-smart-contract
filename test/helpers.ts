import { ethers } from "hardhat";

export function generatePetitionId(prefix: string = "petition"): string {
  return ethers.keccak256(
    ethers.toUtf8Bytes(`${prefix}-${Date.now()}-${Math.random()}`)
  );
}

export function getCurrentTimestamp(): number {
  return Math.floor(Date.now() / 1000);
}

export function futureTimestamp(secondsFromNow: number): number {
  return getCurrentTimestamp() + secondsFromNow;
}

export const ONE_DAY = 86400;
export const ONE_WEEK = 604800;
export const ONE_MONTH = 2592000;

export const CATEGORIES = {
  SOCIAL: 0,
  POLITICAL: 1,
  ENVIRONMENTAL: 2,
  EDUCATION: 3,
  HEALTH: 4,
  HUMAN_RIGHTS: 5,
  ANIMAL_RIGHTS: 6,
  ECONOMIC: 7,
  TECHNOLOGY: 8,
  OTHER: 9,
};

export const PETITION_STATUS = {
  ACTIVE: 0,
  COMPLETED: 1,
  CANCELLED: 2,
};