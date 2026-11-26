import {setGlobalOptions} from 'firebase-functions/v2';
import {initializeApp} from 'firebase-admin/app';

initializeApp();
setGlobalOptions({region: 'southamerica-east1', maxInstances: 10});

export {cancelParticipation} from './cancelParticipation';
export {joinSession} from './joinSession';
export {mirrorPublicEvent} from './publicEvents';
export {cancelEvent, checkInPlayer, removePlayer} from './organizer';
export {reviewCreditPurchase} from './reviewCreditPurchase';
export {claimDeviceToken, notifyCreditApproved, sendReminders} from './reminders';
export {expireWaitlistOffers, joinWaitlist, leaveWaitlist} from './waitlistCallables';
