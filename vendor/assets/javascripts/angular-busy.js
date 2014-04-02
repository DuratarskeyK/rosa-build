/* ============================================================
 * angular-busy.js v3.0.2
 * https://github.com/cgross/angular-busy
 * ============================================================
 * Copyright 2013 Chris Gross

 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:

 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * ============================================================ */

angular.module('cgBusy',['ajoslin.promise-tracker']);

angular.module('cgBusy').value('cgBusyTemplateName','angular-busy.html');

angular.module('cgBusy').directive('cgBusy',['promiseTracker','$compile','$templateCache','cgBusyTemplateName','$http',
  function(promiseTracker,$compile,$templateCache,cgBusyTemplateName,$http){
    return {
      restrict: 'A',
      link: function(scope, element, attrs, fn) {

        var options = scope.$eval(attrs.cgBusy);

        if (typeof options === 'string'){
          options = {tracker:options};
        }

        if (typeof options === 'undefined' || typeof options.tracker === 'undefined'){
          throw new Error('Options for cgBusy directive must be provided (tracker option is required).');
        }

        if (!scope.$cgBusyTracker){
          scope.$cgBusyTracker = {};
        }

        scope.$cgBusyTracker[options.tracker] = promiseTracker(options.tracker);

        var position = element.css('position');
        if (position === 'static' || position === '' || typeof position === 'undefined'){
          element.css('position','relative');
        }

        var indicatorTemplateName = options.template ? options.template : cgBusyTemplateName;

        $http.get(indicatorTemplateName,{cache: $templateCache}).success(function(indicatorTemplate){

          options.backdrop = typeof options.backdrop === 'undefined' ? true : options.backdrop;
          var backdrop = options.backdrop ? '<div class="cg-busy cg-busy-backdrop"></div>' : '';

          var template = '<div class="cg-busy" ng-show="$cgBusyTracker[\''+options.tracker+'\'].active()" ng-animate="\'cg-busy\'" style="display:none">'+ backdrop + indicatorTemplate+'</div>';
          var templateElement = $compile(template)(scope);

          angular.element(templateElement.children()[options.backdrop?1:0])
            .css('position','absolute')
            .css('top',0)
            .css('left',0)
            .css('right',0)
            .css('bottom',0);

          element.append(templateElement);

        }).error(function(data){
          throw new Error('Template specified for cgBusy ('+options.template+') could not be loaded. ' + data);
        });
      }
    };
  }
]);


angular.module("cgBusy").run(["$templateCache", function($templateCache) {

  $templateCache.put("angular-busy.html",
    "<div class=\"cg-busy-default-wrapper\">" +
    "" +
    "   <div class=\"cg-busy-default-sign\">" +
    "" +
    "      <div class=\"cg-busy-default-spinner\">" +
    "         <div class=\"bar1\"></div>" +
    "         <div class=\"bar2\"></div>" +
    "         <div class=\"bar3\"></div>" +
    "         <div class=\"bar4\"></div>" +
    "         <div class=\"bar5\"></div>" +
    "         <div class=\"bar6\"></div>" +
    "         <div class=\"bar7\"></div>" +
    "         <div class=\"bar8\"></div>" +
    "         <div class=\"bar9\"></div>" +
    "         <div class=\"bar10\"></div>" +
    "         <div class=\"bar11\"></div>" +
    "         <div class=\"bar12\"></div>" +
    "      </div>" +
    "" +
    "      <div class=\"cg-busy-default-text\">Please Wait...</div>" +
    "" +
    "   </div>" +
    "" +
    "</div>"
  );

}]);

