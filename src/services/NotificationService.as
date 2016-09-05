/**
 Copyright (C) 2016  Johan Degraeve
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/gpl.txt>.
 
 */
package services
{
	import com.distriqt.extension.core.Core;
	import com.distriqt.extension.notifications.AuthorisationStatus;
	import com.distriqt.extension.notifications.Notifications;
	import com.distriqt.extension.notifications.Service;
	import com.distriqt.extension.notifications.builders.NotificationBuilder;
	import com.distriqt.extension.notifications.events.AuthorisationEvent;
	import com.distriqt.extension.notifications.events.NotificationEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import Utilities.BgGraphBuilder;
	
	import databaseclasses.BgReading;
	
	import distriqtkey.DistriqtKey;
	
	import events.CalibrationServiceEvent;
	import events.NotificationServiceEvent;
	import events.TimerServiceEvent;
	import events.TransmitterServiceEvent;
	
	/**
	 * This service<br>
	 * - registers for notifications<br>
	 * - defines id's<br>
	 * At the same time this service will at regular intervals set a notification for the end-user<br>
	 * each time again (period to be defined - probably in the settings) the notification will be reset later<br>
	 * Goal is that whenevever the application stops, also this service will not run anymore, hence the notification will expire, the user
	 * will know the application stopped and by just clicking it it will re-open and restart.
	 * 
	 * It also dispatches the notifications as NotificationServiceEvent 
	 */
	public class NotificationService extends EventDispatcher
	{

		[ResourceBundle("notificationservice")]

		private static var _instance:NotificationService = new NotificationService();

		public static function get instance():NotificationService
		{
			return _instance;
		}

		
		private static var initialStart:Boolean = true;
		
		//Notification ID's
		/**
		 * To request extra calibration 
		 */
		public static const ID_FOR_EXTRA_CALIBRATION_REQUEST:int = 1;
		/**
		 * for the notification with currently measured bg value<br>
		 * this is the always on notification
		 */
		public static const ID_FOR_BG_VALUE:int = 2;

		private static const debugMode:Boolean = false;

		public function NotificationService()
		{
			if (_instance != null) {
				throw new Error("RestartNotificationService class constructor can not be used");	
			}
		}
		
		public static function init():void {
			if (!initialStart)
				return;
			else
				initialStart = false;
			
			Core.init();
			Notifications.init(DistriqtKey.distriqtKey);
			if (!Notifications.isSupported) {
				return;
			}
			
			var service:Service = new Service();
			service.enableNotificationsWhenActive = true;
			
			Notifications.service.setup(service);
			
			switch (Notifications.service.authorisationStatus())
			{
				case AuthorisationStatus.AUTHORISED:
					// This device has been authorised.
					// You can register this device and expect to display notifications
					register();
					break;
				
				case AuthorisationStatus.NOT_DETERMINED:
					// You are yet to ask for authorisation to display notifications
					// At this point you should consider your strategy to get your user to authorise
					// notifications by explaining what the application will provide
					Notifications.service.addEventListener(AuthorisationEvent.CHANGED, authorisationChangedHandler);
					Notifications.service.requestAuthorisation();
					break;
				
				case AuthorisationStatus.DENIED:
					// The user has disabled notifications
					// TODO Advise your user of the lack of notifications as you see fit
					break;
			}
			
			function authorisationChangedHandler(event:AuthorisationEvent):void
			{
				switch (event.status) {
					case AuthorisationStatus.AUTHORISED:
						// This device has been authorised.
						// You can register this device and expect to display notifications
						register();
						break;
				}
			}
			
			/**
			 * will obviously register and also add eventlisteners
			 */
			function register():void {
				Notifications.service.addEventListener(NotificationEvent.NOTIFICATION_SELECTED, notificationHandler);
				TransmitterService.instance.addEventListener(TransmitterServiceEvent.BGREADING_EVENT, updateNotificationWithBgLevel);
				TimerService.instance.addEventListener(TimerServiceEvent.BG_READING_NOT_RECEIVED_ON_TIME, bgReadingNotReceivedOnTime);
				CalibrationService.instance.addEventListener(CalibrationServiceEvent.INITIAL_CALIBRATION_EVENT, updateNotificationWithBgLevel);
				Notifications.service.register();
				_instance.dispatchEvent(new NotificationServiceEvent(NotificationServiceEvent.NOTIFICATION_SERVICE_INITIATED_EVENT));
			}
			
			function bgReadingNotReceivedOnTime(event:TimerServiceEvent):void {
				updateNotificationWithBgLevel(null);
			}
			
			function notificationHandler(event:NotificationEvent):void {
				if (debugMode) trace("in Notificationservice notificationHandler at " + (new Date()).toLocaleTimeString());
				var notificationServiceEvent:NotificationServiceEvent = new NotificationServiceEvent(NotificationServiceEvent.NOTIFICATION_EVENT);
				notificationServiceEvent.data = event;
				_instance.dispatchEvent(notificationServiceEvent);
			}
		}
		
		public static function removeBGNotification():void {
			Notifications.service.cancel(NotificationService.ID_FOR_BG_VALUE);
		}
		
		public static function updateNotificationWithBgLevel(be:Event):void {
			var lastBgReading:BgReading = BgReading.lastNoSensor(); 
			var valueToShow:String = "";
			if (lastBgReading != null) {
				if (lastBgReading.calculatedValue != 0) {
					if ((new Date().getTime()) - (60000 * 11) - lastBgReading.timestamp > 0) {
						valueToShow = "---"
					} else {
						valueToShow = BgGraphBuilder.unitizedString(lastBgReading.calculatedValue, true);
						if (!lastBgReading.hideSlope) {
							valueToShow += " " + lastBgReading.slopeArrow();
						}
					}
				}
			} else {
				valueToShow = "---"
			}
			//Notifications.service.cancel(NotificationService.ID_FOR_BG_VALUE);
			Notifications.service.notify(
				new NotificationBuilder()
				.setId(NotificationService.ID_FOR_BG_VALUE)
				.setAlert("koekoek")
				.setTitle(valueToShow)
				.setSound("")
				.enableVibration(false)
				.setOngoing(true)
				.build());
		}
	}
}